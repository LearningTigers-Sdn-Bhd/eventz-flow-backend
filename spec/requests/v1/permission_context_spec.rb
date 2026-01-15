require 'swagger_helper'

RSpec.describe 'V1::PermissionContext', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  PERMISSION_CONTEXT_SCHEMA = {
    type: :object,
    properties: {
      has_writer_permission: { type: :boolean, example: true },
      updated_at: { type: :string, format: :date_time, nullable: true }
    },
    required: %w[has_writer_permission]
  }.freeze

  # ============================================================
  # Test Users and Setup
  # ============================================================
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let!(:writer_permission) { create(:resource_write_permission, user: writer, updated_at: 2.days.ago) }
  let(:regular_user) { create(:user, role: :member) }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/permission_context/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'User ID'

    get('show permission context') do
      tags 'Resources CMS - Permission Context'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Check if a specific user has writer permissions'

      response(200, 'successful - has permission') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => PERMISSION_CONTEXT_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { writer.id }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['has_writer_permission']).to be true
          expect(data['updated_at']).to be_present
        end
      end

      response(200, 'successful - no permission') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => PERMISSION_CONTEXT_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { regular_user.id }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['has_writer_permission']).to be false
          expect(data['updated_at']).to be_nil
        end
      end

      response(404, 'not found - user does not exist') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource not found' } # Default 404 message
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end