require 'swagger_helper'

RSpec.describe 'V1::ResourcesMediaTypes', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  RESOURCE_MEDIA_TYPE_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      name: { type: :string, example: 'Article' },
      description: { type: :string, nullable: true, example: 'Written articles and blog posts' },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id name]
  }.freeze

  # ============================================================
  # Test Users and Setup
  # ============================================================
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let(:visitor) { create(:user, role: :member) }
  let!(:resource_media_type) { create(:resource_media_type, name: "Article", description: "Written content") }
  let!(:deleted_resource_media_type) { create(:resource_media_type, name: "Deleted Type", deleted_at: 1.day.ago) }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/media_types' do
    get('list resource media types') do
      tags 'Resources CMS - Media Types'
      produces 'application/json'
      description 'Public: List all available resource media types (non-deleted only)'

      response(200, 'successful') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => {
              type: :array,
              items: RESOURCE_MEDIA_TYPE_SCHEMA
            }
          }
        )

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          # Should only show non-deleted media types
          expect(data.any? { |m| m['name'] == 'Article' }).to be true
          expect(data.any? { |m| m['name'] == 'Deleted Type' }).to be false
        end
      end
    end

    post('create resource media type') do
      tags 'Resources CMS - Media Types'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Create a new resource media type'

      parameter name: :media_type_params, in: :body, schema: {
        type: :object,
        properties: {
          media_type: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Webinar' },
              description: { type: :string, nullable: true, example: 'Live or recorded webinar sessions' }
            },
            required: %w[name]
          }
        },
        required: %w[media_type]
      }

      response(201, 'created - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_MEDIA_TYPE_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:media_type_params) { { media_type: { name: 'New Media Type', description: 'Created by admin' } } }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:media_type_params) { { media_type: { name: 'Unauthorized Media Type' } } }
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
        let(:media_type_params) { { media_type: { name: nil } } }
        run_test!
      end
    end
  end

  path '/v1/resources/media_types/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Media Type ID'

    get('show resource media type') do
      tags 'Resources CMS - Media Types'
      produces 'application/json'
      description 'Public: Get details of a specific resource media type'

      response(200, 'successful') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_MEDIA_TYPE_SCHEMA
          }
        )

        let(:id) { resource_media_type.id }
        run_test!
      end

      response(404, 'not found - deleted media type') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource media type not found' }
        }

        let(:id) { deleted_resource_media_type.id }
        run_test!
      end

      response(404, 'not found - invalid id') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource media type not found' }
        }

        let(:id) { 99999 }
        run_test!
      end
    end

    put('update resource media type') do
      tags 'Resources CMS - Media Types'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Update a resource media type'

      parameter name: :media_type_params, in: :body, schema: {
        type: :object,
        properties: {
          media_type: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Updated Media Type Name' },
              description: { type: :string, nullable: true, example: 'Updated description' }
            }
          }
        }
      }

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_MEDIA_TYPE_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_media_type.id }
        let(:media_type_params) { { media_type: { name: 'Updated Article', description: 'Updated description' } } }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_media_type.id }
        let(:media_type_params) { { media_type: { name: 'Unauthorized Update' } } }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource media type not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        let(:media_type_params) { { media_type: { name: 'Not Found Update' } } }
        run_test!
      end
    end

    delete('delete resource media type') do
      tags 'Resources CMS - Media Types'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Soft delete a resource media type'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_media_type.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_media_type.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource media type not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end

  path '/v1/resources/media_types/{id}/restore' do
    parameter name: :id, in: :path, type: :integer, description: 'Media Type ID'

    post('restore resource media type') do
      tags 'Resources CMS - Media Types'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Restore a soft-deleted resource media type'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_MEDIA_TYPE_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { deleted_resource_media_type.id }
        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['name']).to eq('Deleted Type')
        end
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { deleted_resource_media_type.id }
        run_test!
      end

      response(404, 'not found - already restored') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource media type not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_media_type.id } # Not deleted
        run_test!
      end
    end
  end

  path '/v1/resources/media_types/{id}/force_destroy' do
    parameter name: :id, in: :path, type: :integer, description: 'Media Type ID'

    delete('force destroy resource media type') do
      tags 'Resources CMS - Media Types'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Permanently delete a resource media type'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { deleted_resource_media_type.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { deleted_resource_media_type.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource media type not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end