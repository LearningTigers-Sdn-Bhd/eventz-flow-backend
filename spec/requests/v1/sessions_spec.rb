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
        let(:credentials) { { email: 'member@example.com', password: 'password123' } }
        
        run_test!
        
        schema type: :object,
          properties: {
            token: { type: :string },
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
        let(:credentials) { { email: 'member@example.com', password: 'wrongpassword' } }
        
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
end