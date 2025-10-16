require 'swagger_helper'

RSpec.describe 'V1::Users', type: :request do
  let!(:org_owner) { create(:org_owner) }
  let(:member_user) { create(:member_user) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }
  
  # Note: auth_header is not strictly needed here since we define Authorization per response block.
  # We will keep the necessary parts defined directly within the response blocks.

  # --- /v1/users (Registration) ---
  path '/v1/users' do
    post 'Registers a new user (Member role)' do
      tags 'User Management'
      consumes 'application/json'
      produces 'application/json'
      
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
        
        run_test! do
          expect(User.find_by(email: 'newuser@test.com').role).to eq('member')
        end
        
        schema type: :object, properties: { 
          access_token: { type: :string }, 
          user: { 
            type: :object, 
            properties: {
              id: { type: :integer }, 
              email: { type: :string }, 
              full_name: { type: :string },
              role: { type: :string }
            }
          }
        }
      end
      
      response '422', 'Validation error' do
        let(:user) { { user: { email: 'invalid_email', password: '123' } } }
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
        # ✅ Token is correctly defined here
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
        # Schema is correctly defined inline here
        schema type: :object,
          properties: {
            id: { type: :integer },
            email: { type: :string, format: :email },
            full_name: { type: :string, nullable: true },
            phone: { type: :string, nullable: true }
          },
          required: ['id', 'email']
      end
        
      response '401', 'Unauthorized (Missing JWT)' do
        let(:Authorization) { 'Bearer invalid' }
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
      
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          full_name: { type: :string, example: 'Updated Name' },
          phone: { type: :string, example: '1234567890' }
        }
      }

      response '200', 'Profile updated successfully' do
        # ✅ Token is correctly defined here
        let(:Authorization) { "Bearer #{member_token}" }
        let(:user) { { user: { full_name: 'Updated Name' } } }
        run_test!
        # 🛑 FIX: Replace the failing '$ref' with the inline schema definition
        # schema '$ref' => '#/components/schemas/User' # Removed this line
        schema type: :object,
          properties: {
            id: { type: :integer },
            email: { type: :string, format: :email },
            full_name: { type: :string, nullable: true },
            phone: { type: :string, nullable: true }
          },
          required: ['id', 'email']
      end

      response '422', 'Validation error' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:user) { { user: { full_name: '' } } }
        run_test!
      end
    end
  end
end