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

  describe 'POST /v1/auth/register' do
    context 'when the request is valid' do
      it 'creates a new user and returns token' do
        expect do
          post '/v1/auth/register', params: { user: valid_attributes }
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('access_token')
        expect(json_response['data']).to have_key('refresh_token')
        expect(json_response['data']).to have_key('user')
        expect(json_response['data']['user']['email']).to eq('test@example.com')
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

      it 'returns validation errors for missing password' do
        post '/v1/auth/register', params: {
          user: valid_attributes.except(:password)
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['success']).to be false
      end
    end

    context 'with duplicate email' do
      before { create(:user, email: 'test@example.com') }
      it 'returns an error for duplicate email' do
        post '/v1/auth/register', params: {
          user: valid_attributes
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe 'POST /v1/auth/login' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password', password_confirmation: 'password') }

    context 'with valid credentials' do
      it 'returns a token and user details' do
        post '/v1/auth/login', params: { email: 'test@example.com', password: 'password' }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('access_token')
        expect(json_response['data']).to have_key('refresh_token')
        expect(json_response['data']['user']['email']).to eq('test@example.com')
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized error for wrong password' do
        post '/v1/auth/login', params: { email: 'test@example.com', password: 'wrong_password' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Authentication failed')
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['field']).to eq('password')
        expect(json_response['errors'].first['message']).to eq('Invalid password')
      end

      it 'returns unauthorized error for non-existent email' do
        post '/v1/auth/login', params: { email: 'nonexistent@example.com', password: 'password' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Authentication failed')
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['field']).to eq('email')
        expect(json_response['errors'].first['message']).to eq('Email not found')
      end

      it 'returns unauthorized error for inactive account' do
        inactive_user = create(:user, email: 'inactive@example.com', password: 'password', password_confirmation: 'password', status: :inactive)
        post '/v1/auth/login', params: { email: 'inactive@example.com', password: 'password' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Authentication failed')
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['field']).to eq('account')
        expect(json_response['errors'].first['message']).to eq('Account is inactive')
      end
    end
  end

  describe 'DELETE /v1/auth/logout' do
    let!(:user) { create(:user) }
    let(:auth_headers_hash) { auth_headers(user) }

    it 'invalidates the token by updating the jti' do
      old_jti = user.jti

      delete '/v1/auth/logout', headers: auth_headers_hash

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Logged out successfully')
      expect(user.reload.jti).not_to eq(old_jti)
    end

    it 'returns unauthorized error if user without token' do
      delete '/v1/auth/logout'

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['success']).to be false
      expect(json_response['message']).to eq('Unauthorized')
      expect(json_response['errors']).to eq([])
    end
  end

  describe 'POST /v1/auth/refresh_token' do
    let!(:user) { create(:user) }
    let(:tokens) { JwtService.generate_tokens(user) }

    context 'with valid refresh token' do
      it 'returns new access_token, refresh_token, and expires_at' do
        post '/v1/auth/refresh_token', params: { refresh_token: tokens[:refresh_token] }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('access_token')
        expect(json_response['data']).to have_key('refresh_token')
        expect(json_response['data']).to have_key('expires_at')
      end
    end

    context 'with invalid refresh token' do
      it 'returns error for invalid refresh token' do
        post '/v1/auth/refresh_token', params: { refresh_token: 'invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end

      it 'returns error with access token instead of refresh token' do
        post '/v1/auth/refresh_token', params: { refresh_token: tokens[:access_token] }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end

    context 'with revoked refresh token' do
      it 'returns error when user jti has changed' do
        refresh_token = tokens[:refresh_token]
        user.update!(jti: SecureRandom.uuid)

        post '/v1/auth/refresh_token', params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end
  end
end
