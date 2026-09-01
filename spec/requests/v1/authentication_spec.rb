require 'rails_helper'

RSpec.describe 'V1::Authentication', type: :request do
  let(:valid_attributes) do
    {
      email: 'test@example.com',
      password: 'password',
      password_confirmation: 'password',
      full_name: 'Test User'
    }
  end

  # Helper to access signed cookies from the response/cookie jar
  def response_signed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash).signed
  end

  describe 'POST /v1/auth/register' do
    context 'when the request is valid' do
      it 'creates a new user, session, and returns token' do
        expect do
          post '/v1/auth/register', params: { user: valid_attributes }
        end.to change(User, :count).by(1)
           .and change(UserSession, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('access_token')
        expect(json_response['data']).to have_key('session_id')
        
        # Verify cookie using signed helper
        expect(response_signed_cookies['refresh_token']).to be_present
      end
    end

    context 'when the request is invalid' do
      it 'returns validation errors for invalid email' do
        post '/v1/auth/register', params: {
          user: valid_attributes.merge(email: 'invalid-email')
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe 'POST /v1/auth/login' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password', password_confirmation: 'password') }

    context 'with valid credentials' do
      it 'returns a token, creates session, and sets cookie' do
        expect do
            post '/v1/auth/login', params: { email: 'test@example.com', password: 'password' }
        end.to change(UserSession, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('access_token')
        expect(json_response['data']).to have_key('session_id')
        expect(response_signed_cookies['refresh_token']).to be_present
      end

      it "flags a pure business matching admin so the frontend can skip the generic dashboard" do
        event = create(:event)
        create(:event_assignment, event: event, user: user, role: :business_matching_admin)

        post '/v1/auth/login', params: { email: 'test@example.com', password: 'password' }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user']['is_pure_business_matching_admin']).to eq(true)
        expect(json_response['data']['user']['business_matching_admin_event_ids']).to eq([event.id.to_s])
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized error' do
        post '/v1/auth/login', params: { email: 'test@example.com', password: 'wrong_password' }

        expect(response).to have_http_status(:unauthorized)
        expect(response_signed_cookies['refresh_token']).to be_nil
      end

      # Account-enumeration guard (audit #5). Unknown email, wrong password and
      # inactive account must be indistinguishable — same status, same body.
      it 'returns an identical response for unknown email, wrong password and inactive account' do
        create(:user, email: 'inactive@example.com', password: 'password',
                      password_confirmation: 'password', status: :inactive)

        post '/v1/auth/login', params: { email: 'nobody@example.com', password: 'password' }
        unknown_email = [response.status, response.body]

        post '/v1/auth/login', params: { email: 'test@example.com', password: 'wrong_password' }
        wrong_password = [response.status, response.body]

        post '/v1/auth/login', params: { email: 'inactive@example.com', password: 'password' }
        inactive_account = [response.status, response.body]

        expect(unknown_email).to eq(wrong_password)
        expect(inactive_account).to eq(wrong_password)
        expect(json_response['message']).to eq('Invalid email or password')
      end

      # Timing guard: the dummy digest burned on the no-account path must cost the
      # same as a real one, or response latency still reveals which emails exist.
      it 'builds the dummy password digest at the same bcrypt cost as a real user' do
        dummy_cost = BCrypt::Password.new(V1::AuthenticationController.dummy_password_digest).cost

        expect(dummy_cost).to eq(BCrypt::Password.new(user.password_digest).cost)
      end
    end
  end

  describe 'DELETE /v1/auth/logout' do
    let!(:user) { create(:user, password: 'password', password_confirmation: 'password') }
    
    it 'revokes the session and clears cookie' do
        # 1. Login to set the cookie
        post '/v1/auth/login', params: { email: user.email, password: 'password' }
        expect(response).to have_http_status(:ok)
        
        session_id = json_response['data']['session_id']
        access_token = json_response['data']['access_token']
        headers = { 'Authorization' => "Bearer #{access_token}" }

        expect(response_signed_cookies['refresh_token']).to be_present

        # 2. Logout (send cookie + auth header)
        delete '/v1/auth/logout', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['message']).to eq('Logged out successfully')
        
        # Verify session revoked
        expect(UserSession.find(session_id).revoked?).to be true
        
        # Verify cookie cleared (nil or empty)
        expect(response_signed_cookies['refresh_token']).to be_blank
    end
  end

  describe 'POST /v1/auth/refresh_token' do
    let!(:user) { create(:user, password: 'password', password_confirmation: 'password') }

    context 'with valid refresh token in cookie' do
      it 'rotates tokens and updates cookie' do
        # 1. Login to set the cookie
        post '/v1/auth/login', params: { email: user.email, password: 'password' }
        original_cookie = response_signed_cookies['refresh_token']
        original_session_id = json_response['data']['session_id']
        
        # 2. Refresh (sends cookie automatically)
        post '/v1/auth/refresh_token'

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to have_key('access_token')
        
        new_cookie = response_signed_cookies['refresh_token']
        expect(new_cookie).to be_present
        expect(new_cookie).not_to eq(original_cookie)
        
        # Verify session updated (rotated)
        session = UserSession.find(original_session_id)
        expect(session.refresh_token_hash).to eq(JwtService.hash_token(new_cookie))
      end
    end

    context 'with refresh token in params (fallback)' do
      let!(:tokens) { JwtService.generate_tokens(user) }
      
      it 'rotates tokens and sets cookie' do
        post '/v1/auth/refresh_token', params: { refresh_token: tokens[:refresh_token] }

        expect(response).to have_http_status(:ok)
        expect(response_signed_cookies['refresh_token']).to be_present
      end
    end

    context 'with invalid refresh token' do
      it 'does not clear the refresh cookie when refresh is rejected' do
        post '/v1/auth/login', params: { email: user.email, password: 'password' }
        original_cookie = response_signed_cookies['refresh_token']
        UserSession.find(json_response['data']['session_id']).revoke!

        post '/v1/auth/refresh_token'

        expect(response).to have_http_status(:unauthorized)
        expect(response_signed_cookies['refresh_token']).to eq(original_cookie)
      end

      it 'returns unprocessable_content if cookie is tampered and clears cookie' do
        # 1. Login to set cookie
        post '/v1/auth/login', params: { email: user.email, password: 'password' }
        
        # 2. Corrupt the cookie manually
        cookies['refresh_token'] = 'invalid_garbage'
        
        post '/v1/auth/refresh_token' # Sends the bad cookie

        expect(response).to have_http_status(:unprocessable_content)
        expect(response_signed_cookies['refresh_token']).to be_blank
      end

      it 'returns unauthorized if token is invalid (via param)' do
         post '/v1/auth/refresh_token', params: { refresh_token: 'invalid.jwt.token' }
         
         expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /v1/auth/sessions' do
    let!(:user) { create(:user) }
    let(:tokens) { JwtService.generate_tokens(user) }
    let(:headers) { { 'Authorization' => "Bearer #{tokens[:access_token]}" } }
    
    it 'lists active sessions' do
      get '/v1/auth/sessions', headers: headers
      
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['id']).to eq(tokens[:session_id])
    end
  end

  describe 'DELETE /v1/auth/sessions/:id' do
    let!(:user) { create(:user) }
    let!(:session1) { UserSession.create!(user: user, jti: '1', refresh_token_hash: '1', expires_at: 1.day.from_now) }
    let!(:session2) { UserSession.create!(user: user, jti: '2', refresh_token_hash: '2', expires_at: 1.day.from_now) }
    
    # Authenticate with session1
    let(:token) { JwtService.encode({ user_id: user.id, jti: '1', role: user.role }) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it 'revokes the specified session' do
      delete "/v1/auth/sessions/#{session2.id}", headers: headers
      
      expect(response).to have_http_status(:ok)
      expect(session2.reload.revoked?).to be true
      expect(session1.reload.revoked?).to be false
    end
  end
end
