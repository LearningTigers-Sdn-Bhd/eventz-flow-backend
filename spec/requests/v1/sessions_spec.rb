require 'swagger_helper'

RSpec.describe 'V1::Sessions', type: :request do
  # NOTE: This uses the same logic and paths as the refactored spec from the previous turn.
  let!(:member_user) { create(:user, role: :member, email: 'member@example.com', password: 'password123', password_confirmation: 'password123', full_name: 'Regular Member') }
  
  # The old POST /v1/users test has been moved into the users_spec.rb (as shown previously)

  path '/v1/login' do
    post 'Authenticates user and retrieves JWT token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: 'member@example.com' },
          password: { type: :string, example: 'password123' }
        },
        required: [ 'email', 'password' ]
      }

      response '200', 'Successful login' do
        let(:credentials) { { user: { email: 'member@example.com', password: 'password123' } } }
        
        run_test!
        
        schema type: :object,
          properties: {
            access_token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                email: { type: :string },
                role: { type: :string, enum: ['org_owner', 'manager', 'member'] }
              }
            }
          }
      end

      response '401', 'Invalid credentials' do
        let(:credentials) { { user: { email: 'member@example.com', password: 'wrongpassword' } } }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
        end
        
        schema type: :object,
          properties: {
            error: { type: :string, example: 'Unauthorized' },
            message: { type: :string, example: 'Invalid email or password' }
          }
      end
    end
  end

  path '/v1/refresh' do
    post 'Refreshes JWT access token using the Refresh Token cookie' do
      tags 'Authentication'
      produces 'application/json'

      # IMPORTANT: This endpoint is authenticated via the Refresh Token cookie,
      # which is handled automatically by the client (browser), so no explicit
      # 'Authorization' parameter is needed in the header here.

      response '200', 'New access token generated successfully' do
        # We need a valid login run_test! here to generate the cookie first
        # Use a mock login sequence or a helper method to set the cookie for the test context
        before do
          post '/v1/login', params: { user: { email: member_user.email, password: 'password123' } }, as: :json
        end
        let(:credentials) { nil } # Credentials not sent in body for this endpoint

        header 'Set-Cookie', schema: {
          type: :string,
          example: 'refresh_token=NEW_TOKEN_HASH; HttpOnly; Secure; SameSite=Strict'
        }, description: 'Sets a new secure HttpOnly Refresh Token cookie'

        run_test!

        schema type: :object,
          properties: {
            access_token: { type: :string, description: 'The new, short-lived JWT Access Token' }
          },
          required: ['access_token']
      end

      response '401', 'Unauthorized (Invalid or missing Refresh Token)' do
        let(:credentials) { nil } # No body parameters

        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
        end

        schema type: :object,
          properties: {
            error: { type: :string, example: 'Unauthorized' },
            message: { type: :string, example: 'Refresh token is invalid or expired.' }
          }
      end
    end
  end

  # spec/requests/v1/sessions_spec.rb (Corrected /v1/logout path)

  path '/v1/logout' do
    delete 'Logs out the user by deleting the Refresh Token cookie' do
      tags 'Authentication'

      # Document the required JWT Access Token header
      parameter name: :Authorization, in: :header, type: :string, required: true, 
                description: 'Bearer JWT Access Token for user identification.'

      response '204', 'Logout successful (No Content)' do
        
        # FIX: Use a dynamic 'let' block to set the request header.
        # This code runs before run_test! and logs the user in to get the JWT.
        let(:Authorization) do
          # 1. Perform login request to generate and retrieve the JWT Access Token
          post '/v1/login', params: { user: { email: member_user.email, password: 'password123' } }, as: :json
          token = JSON.parse(response.body)['access_token']
          
          # 2. Return the Bearer token string to be used as the Authorization header value
          "Bearer #{token}"
        end
        
        # The documentation for the response header remains:
        header 'Set-Cookie', schema: {
          type: :string,
          example: 'refresh_token=; expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; Secure; SameSite=Strict'
        }, description: 'Deletes the Refresh Token cookie by setting an expiration date in the past.'

        # The assertion remains inside the run_test! block
        run_test! do
          expect(response.body).to be_empty
        end
      end
    end
  end
end