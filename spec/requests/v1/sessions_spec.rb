require 'swagger_helper'

RSpec.describe 'V1::Sessions', type: :request do
  # NOTE: This uses the same logic and paths as the refactored spec from the previous turn.
  let!(:member_user) { create(:user, role: :member, email: 'member@example.com', password: 'password123', password_confirmation: 'password123', full_name: 'Regular Member') }

  # The old POST /v1/users test has been moved into the users_spec.rb (as shown previously)

  path '/v1/register' do
    post 'Registers a new user and retrieves JWT token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user_data, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'newuser@example.com' },
              password: { type: :string, example: 'password123' },
              password_confirmation: { type: :string, example: 'password123' },
              full_name: { type: :string, example: 'New User' },
              phone: { type: :string, example: '+1234567890' }
            },
            required: [ 'email', 'password', 'password_confirmation', 'full_name' ]
          }
        },
        required: [ 'user' ]
      }

      response '201', 'User registered successfully' do
        let(:user_data) {
          {
            user: {
              email: 'newuser@example.com',
              password: 'password123',
              password_confirmation: 'password123',
              full_name: 'New User',
              phone: '+1234567890'
            }
          }
        }

        run_test!

        schema type: :object,
          properties: {
            access_token: { type: :string },
            refresh_token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                full_name: { type: :string },
                email: { type: :string },
                role: { type: :string, enum: ['org_owner', 'manager', 'member'] }
              }
            }
          }
      end

      response '422', 'Validation errors' do
        let(:user_data) {
          {
            user: {
              email: 'invalid-email',
              password: '123',
              password_confirmation: '456',
              full_name: ''
            }
          }
        }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_an(Array)
        end

        schema type: :object,
          properties: {
            errors: {
              type: :array,
              items: { type: :string },
              example: ['Email is invalid', 'Password is too short', 'Password confirmation doesn\'t match Password', 'Full name can\'t be blank']
            }
          }
      end
    end
  end

  path '/v1/login' do
    post 'Authenticates user and retrieves JWT token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'member@example.com' },
              password: { type: :string, example: 'password123' }
            },
            required: [ 'email', 'password' ]
          }
        },
        required: [ 'user' ]
      }

      response '200', 'Successful login' do
        let(:credentials) { { user: { email: 'member@example.com', password: 'password123' } } }

        run_test!

        schema type: :object,
          properties: {
            access_token: { type: :string },
            refresh_token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                full_name: { type: :string },
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

  # spec/requests/v1/sessions_spec.rb (Corrected /v1/logout path)

  path '/v1/logout' do
    delete 'Logs out the user by revoking the Refresh Token' do
      tags 'Authentication'

      # Document the required X-Refresh-Token header
      parameter name: :'X-Refresh-Token', in: :header, type: :string, required: true,
                description: 'Refresh token for user identification and logout.'

      response '200', 'Logout successful' do

        # FIX: Use a dynamic 'let' block to set the request header.
        # This code runs before run_test! and logs the user in to get the refresh token.
        let(:'X-Refresh-Token') do
          # 1. Perform login request to generate and retrieve the refresh token
          post '/v1/login', params: { user: { email: member_user.email, password: 'password123' } }, as: :json
          JSON.parse(response.body)['refresh_token']
        end


        # The assertion remains inside the run_test! block
        run_test! do
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Logged out successfully')
        end

        schema type: :object,
          properties: {
            message: { type: :string, example: 'Logged out successfully' }
          }
      end
    end
  end
end
