require 'swagger_helper'

RSpec.describe 'User Role Management', type: :request, openapi_spec: 'v1/swagger.yaml' do
  include AuthHelper

  let(:org_owner)   { create(:user, role: 'org_owner') }
  let(:member_user) { create(:user, role: 'member') }
  let(:target_user) { create(:user, role: 'member') }

  let(:auth_header_owner)  { "Bearer #{generate_jwt(org_owner)}" }
  let(:auth_header_member) { "Bearer #{generate_jwt(member_user)}" }

  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:id) { target_user.id }

  path '/v1/users/{id}/role' do
    put 'Updates a global user\'s role' do
      tags 'User Management'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :user, in: :body, required: true, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              role: { type: :string, enum: %w[org_owner manager member], example: 'manager' }
            },
            required: %w[role]
          }
        },
        required: %w[user]
      }

      # ----------------- 200 OK -----------------
      response '200', 'Role updated successfully' do
        let(:Authorization) { auth_header_owner } # 👈 satisfies rswag
        let(:auth_token) { auth_header_owner }
        let(:user) { { user: { role: 'manager' } } }

        run_test! do
          put role_v1_user_path(id: id),
              headers: json_headers.merge('Authorization' => auth_token),
              params: user.to_json

          puts "Response: #{response.status} #{response.body}"
          expect(response).to have_http_status(:ok)
          expect(target_user.reload.role).to eq('manager')
        end
      end

      # ----------------- 403 Forbidden -----------------
      response '403', 'Forbidden' do
        let(:Authorization) { auth_header_member } # 👈 satisfies rswag
        let(:auth_token) { auth_header_member }
        let(:user) { { user: { role: 'manager' } } }

        run_test! do
          put role_v1_user_path(id: id),
              headers: json_headers.merge('Authorization' => auth_token),
              params: user.to_json

          puts "Response: #{response.status} #{response.body}"
          expect(response).to have_http_status(:forbidden)
        end
      end

      # ----------------- 422 Validation Error -----------------
      response '422', 'Validation Error' do
        let(:Authorization) { auth_header_owner } # 👈 satisfies rswag
        let(:auth_token) { auth_header_owner }
        let(:user) { { user: { role: 'invalid_role_value' } } }

        run_test! do
          put role_v1_user_path(id: id),
              headers: json_headers.merge('Authorization' => auth_token),
              params: user.to_json

          puts "Response: #{response.status} #{response.body}"
          expect(response).to have_http_status(:unprocessable_entity)
          parsed = JSON.parse(response.body)
          expect(parsed['error']).to eq('Validation Error')
        end
      end
    end
  end
end
