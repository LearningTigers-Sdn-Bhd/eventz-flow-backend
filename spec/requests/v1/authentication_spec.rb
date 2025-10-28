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

    context 'when user is not verified' do
      let!(:unverified_user) { create(:user, :unverified) }
      let(:unverified_auth_headers_hash) { auth_headers(unverified_user) }

      it 'allows logout even without verified email' do
        delete '/v1/auth/logout', headers: unverified_auth_headers_hash

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Logged out successfully')
      end
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

    context 'when user is not verified' do
      let!(:unverified_user) { create(:user, :unverified) }
      let(:unverified_tokens) { JwtService.generate_tokens(unverified_user) }

      it 'allows refresh even without verified email' do
        post '/v1/auth/refresh_token', params: { refresh_token: unverified_tokens[:refresh_token] }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']).to have_key('access_token')
        expect(json_response['data']).to have_key('refresh_token')
        expect(json_response['data']).to have_key('expires_at')
      end
    end
  end

  describe 'POST /v1/auth/send-verification-code' do
    let!(:user) { create(:user) }
    let(:auth_headers_hash) { auth_headers(user) }

    context 'when user is authenticated' do
      it 'creates and sends a new verification code' do
        expect do
          post '/v1/auth/send-verification-code', headers: auth_headers_hash
        end.to change(EmailVerification, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Verification code sent successfully')

        # Verify that the EmailVerification was created with correct user
        email_verification = EmailVerification.last
        expect(email_verification.user_id).to eq(user.id)
        expect(email_verification.hashed_code).to be_present
        expect(email_verification.expires_at).to be_present
      end

      it 'revokes any existing verification codes' do
        # Create an existing verification code
        EmailVerification.create_for_user(user)
        first_verification = EmailVerification.where(user_id: user.id).first

        # Send a new code
        post '/v1/auth/send-verification-code', headers: auth_headers_hash

        expect(response).to have_http_status(:ok)

        # The old code should be revoked
        first_verification.reload
        expect(first_verification.revoked_at).to be_present

        # There should be a new non-revoked code
        new_verification = EmailVerification.where(user_id: user.id).order(created_at: :desc).first
        expect(new_verification.id).not_to eq(first_verification.id)
        expect(new_verification.revoked_at).to be_nil
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized error' do
        post '/v1/auth/send-verification-code'

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end

    context 'when user is not verified' do
      let!(:unverified_user) { create(:user, :unverified) }
      let(:unverified_auth_headers_hash) { auth_headers(unverified_user) }

      it 'allows sending verification code even without verified email' do
        expect do
          post '/v1/auth/send-verification-code', headers: unverified_auth_headers_hash
        end.to change(EmailVerification, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
      end
    end
  end

  describe 'POST /v1/auth/verify-email' do
    let!(:user) { create(:user, email_verified_at: nil) }
    let(:auth_headers_hash) { auth_headers(user) }

    context 'when verification code is valid' do
      it 'verifies the user email successfully' do
        # Generate a verification code
        raw_code = EmailVerification.create_for_user(user)

        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: raw_code }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Email verified successfully')
        expect(json_response['data']['user']['email_verified']).to be true

        # Verify that the user's email is marked as verified in the database
        user.reload
        expect(user.email_verified_at).to be_present

        # Verify that the code was revoked (one-time use)
        verification = EmailVerification.where(user_id: user.id).first
        expect(verification.revoked_at).to be_present
      end

      it 'returns user details with verified email' do
        raw_code = EmailVerification.create_for_user(user)

        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: raw_code }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['user']).to include(
          'id' => user.id,
          'email' => user.email,
          'full_name' => user.full_name,
          'email_verified' => true
        )
      end
    end

    context 'when verification code is invalid' do
      it 'returns unauthorized error for invalid code' do
        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: '123456' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Invalid verification code')
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['field']).to eq('code')
        expect(json_response['errors'].first['message']).to eq('Invalid or expired code')

        # Verify that the user's email was not verified
        user.reload
        expect(user.email_verified_at).to be_nil
      end

      it 'returns unauthorized error for expired code' do
        # Create and manually expire a code
        raw_code = EmailVerification.create_for_user(user)
        verification = EmailVerification.where(user_id: user.id).first
        verification.update!(expires_at: 1.minute.ago)

        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: raw_code }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Invalid verification code')
      end

      it 'returns unauthorized error for already used code' do
        raw_code = EmailVerification.create_for_user(user)

        # Use the code once
        EmailVerification.verify_code(user, raw_code)

        # Try to use it again
        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: raw_code }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end

      it 'returns unauthorized error for code belonging to different user' do
        other_user = create(:user)
        raw_code = EmailVerification.create_for_user(other_user)

        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: raw_code }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end

    context 'when verification code is missing' do
      it 'returns unprocessable_content error' do
        post '/v1/auth/verify-email',
             headers: auth_headers_hash,
             params: { code: '' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Verification code is required')
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['field']).to eq('code')
        expect(json_response['errors'].first['message']).to eq('Verification code is required')
      end

      it 'returns error when code parameter is not provided' do
        post '/v1/auth/verify-email', headers: auth_headers_hash

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Verification code is required')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized error' do
        post '/v1/auth/verify-email', params: { code: '123456' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['success']).to be false
      end
    end

    context 'when unverified user verifies their email' do
      let!(:unverified_user) { create(:user, :unverified) }
      let(:unverified_auth_headers_hash) { auth_headers(unverified_user) }

      it 'allows verification code submission even when email is not verified' do
        raw_code = EmailVerification.create_for_user(unverified_user)

        post '/v1/auth/verify-email',
             headers: unverified_auth_headers_hash,
             params: { code: raw_code }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Email verified successfully')

        # Verify that the user's email is now marked as verified
        unverified_user.reload
        expect(unverified_user.email_verified_at).to be_present
      end
    end
  end
end
