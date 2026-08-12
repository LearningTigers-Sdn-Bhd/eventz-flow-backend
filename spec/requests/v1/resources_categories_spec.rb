require 'swagger_helper'

RSpec.describe 'V1::ResourcesCategories', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  RESOURCE_CATEGORY_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      name: { type: :string, example: 'Corporate Events' },
      description: { type: :string, nullable: true, example: 'Business and corporate event management resources' },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id name]
  }.freeze

  # ============================================================
  # Test Users and Setup
  # ============================================================
  let!(:org_owner) { create(:user, role: :org_owner) }
  let!(:writer) { create(:user, role: :member) }
  let!(:visitor) { create(:user, role: :member) }
  let!(:resource_category) { create(:resource_category, name: "Corporate Events", description: "Business events") }
  let!(:deleted_resource_category) { create(:resource_category, name: "Deleted Category", deleted_at: 1.day.ago) }

  # Grant writer permissions
  before { create(:resource_write_permission, user: writer) }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/categories' do
    get('list resource categories') do
      tags 'Resources CMS - Categories'
      produces 'application/json'
      description 'Public: List all available resource categories (non-deleted only)'

      response(200, 'successful') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => {
              type: :array,
              items: RESOURCE_CATEGORY_SCHEMA
            }
          }
        )

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          # Should only show non-deleted categories
          expect(data.any? { |c| c['name'] == 'Corporate Events' }).to be true
          expect(data.any? { |c| c['name'] == 'Deleted Category' }).to be false
        end
      end
    end

    post('create resource category') do
      tags 'Resources CMS - Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin or Writer: Create a new resource category'

      parameter name: :category_params, in: :body, schema: {
        type: :object,
        properties: {
          category: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Wedding Planning' },
              description: { type: :string, nullable: true, example: 'Wedding event planning and management resources' }
            },
            required: %w[name]
          }
        },
        required: %w[category]
      }

      response(201, 'created - admin') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_CATEGORY_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:category_params) { { category: { name: 'New Admin Category', description: 'Created by admin' } } }
        run_test!
      end

      response(201, 'created - writer') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_CATEGORY_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:category_params) { { category: { name: 'New Writer Category', description: 'Created by writer' } } }
        run_test!
      end

      response(403, 'forbidden - visitor without write permission') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(visitor)['Authorization'] }
        let(:category_params) { { category: { name: 'Unauthorized Category' } } }
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
        let(:category_params) { { category: { name: nil } } }
        run_test!
      end
    end
  end

  path '/v1/resources/categories/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Category ID'

    get('show resource category') do
      tags 'Resources CMS - Categories'
      produces 'application/json'
      description 'Public: Get details of a specific resource category'

      response(200, 'successful') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_CATEGORY_SCHEMA
          }
        )

        let(:id) { resource_category.id }
        run_test!
      end

      response(404, 'not found - deleted category') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource category not found' }
        }

        let(:id) { deleted_resource_category.id }
        run_test!
      end

      response(404, 'not found - invalid id') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource category not found' }
        }

        let(:id) { 99999 }
        run_test!
      end
    end

    put('update resource category') do
      tags 'Resources CMS - Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Update a resource category'

      parameter name: :category_params, in: :body, schema: {
        type: :object,
        properties: {
          category: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Updated Category Name' },
              description: { type: :string, nullable: true, example: 'Updated description' }
            }
          }
        }
      }

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_CATEGORY_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_category.id }
        let(:category_params) { { category: { name: 'Updated Corporate Events', description: 'Updated description' } } }
        run_test!
      end

      response(403, 'forbidden - writer cannot update') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_category.id }
        let(:category_params) { { category: { name: 'Unauthorized Update' } } }
        run_test!
      end

      response(403, 'forbidden - visitor') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(visitor)['Authorization'] }
        let(:id) { resource_category.id }
        let(:category_params) { { category: { name: 'Unauthorized Update' } } }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource category not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        let(:category_params) { { category: { name: 'Not Found Update' } } }
        run_test!
      end
    end

    delete('delete resource category') do
      tags 'Resources CMS - Categories'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Soft delete a resource category'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_category.id }
        run_test!
      end

      response(403, 'forbidden - writer cannot delete') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_category.id }
        run_test!
      end

      response(403, 'forbidden - visitor') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(visitor)['Authorization'] }
        let(:id) { resource_category.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource category not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end

  path '/v1/resources/categories/{id}/restore' do
    parameter name: :id, in: :path, type: :integer, description: 'Category ID'

    post('restore resource category') do
      tags 'Resources CMS - Categories'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Restore a soft-deleted resource category'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_CATEGORY_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { deleted_resource_category.id }
        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['name']).to eq('Deleted Category')
        end
      end

      response(403, 'forbidden - writer cannot restore') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { deleted_resource_category.id }
        run_test!
      end

      response(404, 'not found - already restored') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource category not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_category.id } # Not deleted
        run_test!
      end
    end
  end

  path '/v1/resources/categories/{id}/force_destroy' do
    parameter name: :id, in: :path, type: :integer, description: 'Category ID'

    delete('force destroy resource category') do
      tags 'Resources CMS - Categories'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Permanently delete a resource category'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { deleted_resource_category.id }
        run_test!
      end

      response(403, 'forbidden - writer cannot force destroy') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { deleted_resource_category.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource category not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end