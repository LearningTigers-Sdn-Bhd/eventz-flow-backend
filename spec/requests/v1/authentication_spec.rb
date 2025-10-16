# spec/requests/v1/authentication_spec.rb
require 'rails_helper'
# If you are using Swagger/Rswag, replace 'rails_helper' with 'swagger_helper'

RSpec.describe 'V1::Authentication', type: :request do
  let!(:user) { create(:user, email: 'test@example.com', password: 'password123', password_confirmation: 'password123') }

  # --- Helpers for Token/Cookie Management ---
  # Note: The refresh token factory now provides 'raw_token' via the transient attribute.
  def get_refresh_token_cookie(response)
    # Extracts the value from the 'Set-Cookie' header for the refresh_token
    cookie_string = response.headers['Set-Cookie'].split(';').find { |c| c.strip.start_with?('refresh_token=') }
    cookie_value = cookie_string.split('=').last if cookie_string
    # The value is signed and URL-encoded. We need to grab the full signed string.
    
    # Since we use ActionController::Cookies in the controller, 
    # the response will contain the *signed* cookie value.
    cookie = Rack::Utils.parse_set_cookie(response.headers['Set-Cookie'].split(';').first)
    cookie['refresh_token']
  end

  # =========================================================================
  # POST /v1/login
  # =========================================================================
  describe 'POST /v1/login' do
    let(:valid_params) { { user: { email: 'test@example.com', password: 'password123' } } }
    let(:invalid_params) { { user: { email: 'test@example.com', password: 'wrong' } } }

    context 'with valid credentials' do
      before { post '/v1/login', params: valid_params, as: :json }

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns an access_token' do
        expect(json).to include('access_token')
      end

      it 'sets an HttpOnly signed refresh_token cookie' do
        expect(response.headers['Set-Cookie']).to match(/refresh_token=/)
        # Check for essential security flags
        expect(response.headers['Set-Cookie']).to include('HttpOnly') 
      end

      it 'creates a RefreshToken record in the database' do
        expect(user.refresh_tokens.active.count).to eq(1)
      end
    end

    context 'with invalid credentials' do
      before { post '/v1/login', params: invalid_params, as: :json }

      it 'returns 401 Unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a RefreshToken record' do
        expect(user.refresh_tokens.count).to eq(0)
      end
    end
  end

  # =========================================================================
  # POST /v1/refresh (Token Rotation)
  # =========================================================================
  describe 'POST /v1/refresh' do
    let(:old_raw_token) { AuthenticationService.generate_secure_token }
    let!(:old_db_record) do
      user.refresh_tokens.create!(
        token_hash: AuthenticationService.hash_token(old_raw_token),
        expires_at: 7.days.from_now
      )
    end
    
    # Simulate a client sending the cookie
    let(:active_cookie) { { refresh_token: old_raw_token } }

    context 'with a valid, active refresh_token cookie' do
      before { post '/v1/refresh', params: {}, headers: { 'Cookie' => "refresh_token=#{old_raw_token}" } }

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a new access_token' do
        expect(json).to include('access_token')
        # Simple check that the new token is different from the old (if we had the old one)
        new_payload = JsonWebToken.decode(json['access_token']) 
        expect(new_payload[:user_id]).to eq(user.id)
      end

      it 'sets a NEW HttpOnly signed refresh_token cookie' do
        expect(response.headers['Set-Cookie']).to match(/refresh_token=/)
        # Verify the cookie value has changed (token rotation)
        new_raw_token = cookies[:refresh_token]
        expect(new_raw_token).not_to eq(old_raw_token)
      end

      it 'revokes the old RefreshToken record' do
        old_db_record.reload
        expect(old_db_record.revoked_at).not_to be_nil
        expect(old_db_record).not_to be_active
      end

      it 'creates a new RefreshToken record in the database' do
        # Should now have 1 new active token and 1 revoked token
        expect(user.refresh_tokens.active.count).to eq(1)
        expect(user.refresh_tokens.count).to eq(2)
      end
    end

    context 'with an expired refresh_token cookie' do
      let!(:expired_record) do
        user.refresh_tokens.create!(
          token_hash: AuthenticationService.hash_token("expired_token"),
          expires_at: 1.day.ago # Expired
        )
      end
      let(:expired_cookie) { { refresh_token: "expired_token" } }

      before { post '/v1/refresh', params: {}, headers: { 'Cookie' => "refresh_token=expired_token" } }

      it 'returns 401 Unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'clears the cookie' do
        expect(response.headers['Set-Cookie']).to match(/refresh_token=;/)
        expect(response.headers['Set-Cookie']).to include('expires=Thu, 01 Jan 1970')
      end
    end
  end

  # =========================================================================
  # DELETE /v1/logout
  # =========================================================================
  describe 'DELETE /v1/logout' do
    let!(:jwt_token) { JsonWebToken.encode(user_id: user.id) }
    let(:auth_header) { { 'Authorization' => "Bearer #{jwt_token}" } }
    
    let(:raw_token_to_revoke) { AuthenticationService.generate_secure_token }
    let!(:db_record_to_revoke) do
      user.refresh_tokens.create!(
        token_hash: AuthenticationService.hash_token(raw_token_to_revoke),
        expires_at: 7.days.from_now
      )
    end
    
    let(:logout_cookie) { { refresh_token: raw_token_to_revoke } }
    
    # We must be authenticated with the JWT to hit this endpoint
    context 'when authenticated via JWT' do
      before do
        delete '/v1/logout', headers: auth_header.merge('Cookie' => "refresh_token=#{raw_token_to_revoke}")
      end

      it 'returns 204 No Content' do
        expect(response).to have_http_status(:no_content)
      end

      it 'revokes the refresh token record in the database' do
        db_record_to_revoke.reload
        expect(db_record_to_revoke.revoked_at).not_to be_nil
        expect(db_record_to_revoke).not_to be_active
      end

      it 'clears the refresh_token cookie from the client' do
        expect(response.headers['Set-Cookie']).to match(/refresh_token=;/)
        expect(response.headers['Set-Cookie']).to include('expires=Thu, 01 Jan 1970')
      end
    end

    context 'when only the JWT is present (no refresh token cookie)' do
      before do
        delete '/v1/logout', headers: auth_header
      end

      it 'returns 204 No Content' do
        expect(response).to have_http_status(:no_content)
      end

      it 'does not change the state of any existing refresh tokens' do
        db_record_to_revoke.reload
        expect(db_record_to_revoke).to be_active
      end
    end
  end
  
  # =========================================================================
  # API KEY Authentication Tests (New Requirement)
  # =========================================================================
  describe 'API Key Authentication' do
    let!(:raw_api_key) { ApiKey.create_key_for_user(user) }
    let!(:protected_url) { '/v1/events' } # Assuming /v1/events requires authentication

    context 'with a valid raw API Key' do
      let(:api_key_header) { { 'Authorization' => raw_api_key } }

      # Use a simple GET request to a protected resource to verify auth
      before { get protected_url, headers: api_key_header }

      it 'returns 200 OK (Authentication successful)' do
        # Assuming the policy allows the user to see some events or an empty array
        expect(response).to have_http_status(:ok)
        expect(ApiKey.find_by(key_hash: AuthenticationService.hash_token(raw_api_key)).last_used_at).not_to be_nil
      end
    end
    
    context 'with an invalid API Key' do
      let(:invalid_key_header) { { 'Authorization' => 'invalid-key-string-longer-than-30-chars' } }

      before { get protected_url, headers: invalid_key_header }

      it 'returns 401 Unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
    
    context 'with a revoked API Key' do
      let!(:revoked_key_record) do
        ApiKey.find_by(key_hash: AuthenticationService.hash_token(raw_api_key)).update!(is_active: false)
      end
      let(:api_key_header) { { 'Authorization' => raw_api_key } } # Still sending the key

      before { get protected_url, headers: api_key_header }

      it 'returns 401 Unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end