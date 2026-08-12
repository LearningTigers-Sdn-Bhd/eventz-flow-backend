require 'swagger_helper'

RSpec.describe 'V1::ResourcesPermissions', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  RESOURCE_WRITE_PERMISSION_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      user_id: { type: :integer, example: 123 },
      is_official: { type: :boolean, example: false },
      status: { type: :string, enum: ['base', 'partnership'], example: 'base' },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id user_id is_official status]
  }.freeze

  # ============================================================
  # Test Users and Setup
  # ============================================================
  let!(:org_owner) { create(:user, role: :org_owner) }
  let!(:writer) { create(:user, role: :member) }
  let!(:visitor) { create(:user, role: :member) }
  let!(:resource_write_permission) { create(:resource_write_permission, user: writer) }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/permissions' do
    get('list resource write permissions') do
      tags 'Resources CMS - Permissions'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: List all user write permissions for resources'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => {
              type: :array,
              items: RESOURCE_WRITE_PERMISSION_SCHEMA
            }
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        run_test!
      end
    end

    post('create resource write permission') do
      tags 'Resources CMS - Permissions'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Grant write permission to a user'

      parameter name: :permission_params, in: :body, schema: {
        type: :object,
        properties: {
          permission: {
            type: :object,
            properties: {
              user_id: { type: :integer, example: 456 },
              is_official: { type: :boolean, example: false },
              status: { type: :string, enum: ['base', 'partnership'], example: 'base' }
            },
            required: %w[user_id]
          }
        },
        required: %w[permission]
      }

      response(201, 'created - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_WRITE_PERMISSION_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:permission_params) { { permission: { user_id: create(:user).id, is_official: false, status: 'base' } } }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:permission_params) { { permission: { user_id: create(:user).id } } }
        run_test!
      end

      response(422, 'unprocessable entity - validation errors') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Validation failed' },
          errors: {
            type: :array,
            items: {
              type: :object,
              properties: {
                field: { type: :string },
                message: { type: :string }
              }
            }
          }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:permission_params) { { permission: { user_id: nil } } }
        run_test!
      end
    end
  end

  path '/v1/resources/permissions/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Permission ID'

    get('show resource write permission') do
      tags 'Resources CMS - Permissions'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Get details of a specific write permission'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_WRITE_PERMISSION_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_write_permission.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_write_permission.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource write permission not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end

    put('update resource write permission') do
      tags 'Resources CMS - Permissions'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Update a user write permission'

      parameter name: :permission_params, in: :body, schema: {
        type: :object,
        properties: {
          permission: {
            type: :object,
            properties: {
              is_official: { type: :boolean, example: true },
              status: { type: :string, enum: ['base', 'partnership'], example: 'partnership' }
            }
          }
        }
      }

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_WRITE_PERMISSION_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_write_permission.id }
        let(:permission_params) { { permission: { is_official: true, status: 'partnership' } } }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_write_permission.id }
        let(:permission_params) { { permission: { is_official: true } } }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource write permission not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        let(:permission_params) { { permission: { is_official: true } } }
        run_test!
      end
    end

    delete('delete resource write permission') do
      tags 'Resources CMS - Permissions'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Revoke write permission from a user'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_write_permission.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_write_permission.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource write permission not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end