# v1/users_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS (Defined as Global Constants) 💡
# =========================================================================

# Standard error schema for 401, 403, 404, 422
ERROR_SCHEMA = {
  type: :object,
  properties: {
    error: { type: :string, description: 'General error message for 401, 403, 404.' },
    errors: {
      type: :array,
      description: 'Validation errors (for 422 responses).',
      additionalProperties: {
        type: :array,
        items: { type: :string }
      }
    }
  }
}.freeze


# Schema for basic User representation (Profile GET/PUT)
USER_SCHEMA = {
  type: :object,
  properties: {
    success: { type: :boolean },
    message: { type: :string },
    data: {
      type: :object,
      properties: {
        id: { type: :integer },
        email: { type: :string, format: :email },
        full_name: { type: :string, nullable: true },
        phone: { type: :string, nullable: true },
        role: { type: :string },
        email_verified: { type: :boolean }
      },
      required: ['id', 'email']
    }
  },
  required: ['success', 'message', 'data']
}.freeze

# Schema for POST /v1/users (Registration) response which includes a token
USER_AUTH_SCHEMA = {
  type: :object,
  properties: {
    user: {
      type: :object,
      properties: {
        id: { type: :integer },
        full_name: { type: :string },
        email: { type: :string },
        role: { type: :string }
      },
      required: ['id', 'full_name', 'email', 'role']
    },
    token: { type: :string, description: 'JWT token for immediate authentication.' }
  },
  required: ['user', 'token']
}.freeze


RSpec.describe 'V1::Users', type: :request do
  let!(:org_owner) { create(:org_owner) }
  let(:member_user) { create(:member_user) }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- /v1/users (Registration) ---
  path '/v1/users' do
    post 'Registers a new user (Member role)' do
      tags 'User Management'
      consumes 'application/json'
      produces 'application/json'

      # Request body schema is fine
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: 'new_user@test.com' },
          password: { type: :string, example: 'securepass' },
          password_confirmation: { type: :string, example: 'securepass' },
          full_name: { type: :string, example: 'Jane Doe' }
        },
        required: [ 'email', 'password', 'password_confirmation', 'full_name' ]
      }

      response '201', 'User created successfully' do
        let(:user) { { user: { email: 'newuser@test.com', password: 'securepassword', password_confirmation: 'securepassword', full_name: 'New Test User' } } }

        # REFACTORED: Use reusable schema constant
        schema USER_AUTH_SCHEMA

        run_test!
      end

      response '422', 'Validation error' do
        let(:user) { { user: { email: 'invalid_email', password: '123' } } }

        # ADDED: Error schema
        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  # --- /v1/users/profile (Profile Management) ---
  path '/v1/users/profile' do

    # --- GET /v1/users/profile ---
    get 'Retrieves the authenticated user\'s profile' do
      tags 'User Management'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      response '200', 'Profile retrieved successfully' do
        let(:Authorization) { "Bearer #{member_token}" }

        # REFACTORED: Use reusable schema constant
        schema USER_SCHEMA

        run_test!
      end

      response '401', 'Unauthorized (Missing JWT)' do
        let(:Authorization) { 'Bearer invalid' }

        # ADDED: Error schema
        schema ERROR_SCHEMA

        run_test!
      end
    end

    # --- PUT /v1/users/profile ---
    put 'Updates the authenticated user\'s profile' do
      tags 'User Management'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      # Request body schema is fine
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          full_name: { type: :string, example: 'Updated Name' },
          phone: { type: :string, example: '1234567890' }
        }
      }

      response '200', 'Profile updated successfully' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:user) { { user: { full_name: 'Updated Name' } } }

        # REFACTORED: Use reusable schema constant
        schema USER_SCHEMA

        run_test!
      end

      response '422', 'Validation error' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:user) { { user: { full_name: '' } } }

        # ADDED: Error schema
        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  # =========================================================================
  # Email Verification Requirement Tests
  # =========================================================================

  describe 'Email Verification Enforcement for Users' do
    let(:unverified_user) { create(:user, :unverified) }
    let(:unverified_token) { JwtService.generate_tokens(unverified_user)[:access_token] }

    context 'when unverified user tries to access profile' do
      it 'returns 403 Forbidden for show' do
        get '/v1/users/profile', headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Email verification required')
      end

      it 'returns 403 Forbidden for update' do
        put '/v1/users/profile',
            headers: { 'Authorization' => "Bearer #{unverified_token}" },
            params: { user: { full_name: 'Updated Name' } }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Email verification required')
      end
    end
  end
end
