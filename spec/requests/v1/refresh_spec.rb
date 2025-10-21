require 'swagger_helper'

RSpec.describe 'V1::Refresh', type: :request do
  let!(:member_user) { create(:user, role: :member, email: 'member@example.com', password: 'password123', password_confirmation: 'password123', full_name: 'Regular Member') }

  path '/v1/refresh' do
    post 'Refreshes JWT access token using the Refresh Token header' do
      tags 'Authentication'
      produces 'application/json'

      # IMPORTANT: This endpoint uses the Refresh Token in HTTP header,
      # not cookies. The refresh token is sent in the X-Refresh-Token header.
      parameter name: :'X-Refresh-Token', in: :header, type: :string, required: true,
                description: 'Refresh token for generating new access token.'

      response '200', 'New access token generated successfully' do
        # First login to get a refresh token
        let(:login_response) do
          post '/v1/login', params: { user: { email: member_user.email, password: 'password123' } }, as: :json
          JSON.parse(response.body)
        end

        # Set the refresh token from login response as the header
        let(:'X-Refresh-Token') { login_response['refresh_token'] }

        run_test!

        schema type: :object,
          properties: {
            access_token: { type: :string, description: 'The new, short-lived JWT Access Token' }
          },
          required: ['access_token']
      end

      response '401', 'Unauthorized (Invalid or missing Refresh Token)' do
        let(:'X-Refresh-Token') { 'invalid_token' }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
        end

        schema type: :object,
          properties: {
            error: { type: :string, example: 'Unauthorized' },
            message: { type: :string, example: 'User not found' }
          }
      end
    end
  end
end
