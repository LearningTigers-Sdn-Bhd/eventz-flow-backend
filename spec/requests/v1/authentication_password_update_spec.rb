require 'swagger_helper'

RSpec.describe 'Password Update', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let(:user) { create(:user, :member, password: 'OldPass123!', password_confirmation: 'OldPass123!') }
  let(:auth_header) { "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }

  path '/v1/auth/password' do
    patch 'Update password for authenticated user' do
      tags 'Auth'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, required: true, schema: { type: :string }, description: 'Bearer JWT token'
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          current_password: { type: :string, example: 'OldPass123!' },
          new_password: { type: :string, example: 'NewPass123!' },
          confirm_new_password: { type: :string, example: 'NewPass123!' }
        },
        required: %w[current_password new_password confirm_new_password]
      }

      response '200', 'Password updated successfully' do
        let(:Authorization) { auth_header }
        let(:payload) do
          {
            current_password: 'OldPass123!',
            new_password: 'NewPass123!',
            confirm_new_password: 'NewPass123!'
          }
        end

        run_test! do
          user.reload
          expect(user.authenticate('NewPass123!')).to be_truthy
          body = JSON.parse(response.body)
          expect(body['data']).to include('access_token', 'refresh_token', 'expires_at')
        end
      end

      response '401', 'Current password incorrect' do
        let(:Authorization) { auth_header }
        let(:payload) do
          {
            current_password: 'WrongOld!',
            new_password: 'NewPass123!',
            confirm_new_password: 'NewPass123!'
          }
        end

        run_test!
      end

      response '422', 'Validation error (password mismatch)' do
        let(:Authorization) { auth_header }
        let(:payload) do
          {
            current_password: 'OldPass123!',
            new_password: 'NewPass123!',
            confirm_new_password: 'Mismatch123!'
          }
        end

        run_test!
      end
    end
  end
end
