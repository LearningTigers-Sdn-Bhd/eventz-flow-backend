require 'swagger_helper'

RSpec.describe 'V1::ResourcesTopics', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  RESOURCE_TOPIC_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      name: { type: :string, example: 'Event Management' },
      description: { type: :string, nullable: true, example: 'Best practices for event planning and management' },
      logo: { type: :string, nullable: true, example: 'https://example.com/logos/event-management.png' },
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
  let!(:resource_topic) { create(:resource_topic, name: "Event Management", description: "Planning and execution") }
  let!(:deleted_resource_topic) { create(:resource_topic, name: "Deleted Topic", deleted_at: 1.day.ago) }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/topics' do
    get('list resource topics') do
      tags 'Resources CMS - Topics'
      produces 'application/json'
      description 'Public: List all available resource topics (non-deleted only)'

      response(200, 'successful') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => {
              type: :array,
              items: RESOURCE_TOPIC_SCHEMA
            }
          }
        )

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          # Should only show non-deleted topics
          expect(data.any? { |t| t['name'] == 'Event Management' }).to be true
          expect(data.any? { |t| t['name'] == 'Deleted Topic' }).to be false
        end
      end
    end

    post('create resource topic') do
      tags 'Resources CMS - Topics'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Create a new resource topic'

      parameter name: :topic_params, in: :body, schema: {
        type: :object,
        properties: {
          topic: {
            type: :object,
            properties: {
              name: { type: :string, example: 'AI in Events' },
              description: { type: :string, nullable: true, example: 'Artificial intelligence applications in event management' },
              logo: { type: :string, nullable: true, example: 'https://example.com/logos/ai-events.png' }
            },
            required: %w[name]
          }
        },
        required: %w[topic]
      }

      response(201, 'created - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_TOPIC_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:topic_params) { { topic: { name: 'AI in Events', description: 'AI applications for events' } } }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:topic_params) { { topic: { name: 'Unauthorized Topic' } } }
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
        let(:topic_params) { { topic: { name: nil } } }
        run_test!
      end
    end
  end

  path '/v1/resources/topics/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Topic ID'

    get('show resource topic') do
      tags 'Resources CMS - Topics'
      produces 'application/json'
      description 'Public: Get details of a specific resource topic'

      response(200, 'successful') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_TOPIC_SCHEMA
          }
        )

        let(:id) { resource_topic.id }
        run_test!
      end

      response(404, 'not found - deleted topic') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource topic not found' }
        }

        let(:id) { deleted_resource_topic.id }
        run_test!
      end

      response(404, 'not found - invalid id') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource topic not found' }
        }

        let(:id) { 99999 }
        run_test!
      end
    end

    put('update resource topic') do
      tags 'Resources CMS - Topics'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Update a resource topic'

      parameter name: :topic_params, in: :body, schema: {
        type: :object,
        properties: {
          topic: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Updated Topic Name' },
              description: { type: :string, nullable: true, example: 'Updated description' },
              logo: { type: :string, nullable: true, example: 'https://example.com/logos/updated.png' }
            }
          }
        }
      }

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_TOPIC_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_topic.id }
        let(:topic_params) { { topic: { name: 'Updated Event Management', description: 'Updated description' } } }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_topic.id }
        let(:topic_params) { { topic: { name: 'Unauthorized Update' } } }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource topic not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        let(:topic_params) { { topic: { name: 'Not Found Update' } } }
        run_test!
      end
    end

    delete('delete resource topic') do
      tags 'Resources CMS - Topics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Soft delete a resource topic'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_topic.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_topic.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource topic not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end

  path '/v1/resources/topics/{id}/restore' do
    parameter name: :id, in: :path, type: :integer, description: 'Topic ID'

    post('restore resource topic') do
      tags 'Resources CMS - Topics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Restore a soft-deleted resource topic'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_TOPIC_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { deleted_resource_topic.id }
        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['name']).to eq('Deleted Topic')
        end
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { deleted_resource_topic.id }
        run_test!
      end

      response(404, 'not found - already restored') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource topic not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_topic.id } # Not deleted
        run_test!
      end
    end
  end

  path '/v1/resources/topics/{id}/force_destroy' do
    parameter name: :id, in: :path, type: :integer, description: 'Topic ID'

    delete('force destroy resource topic') do
      tags 'Resources CMS - Topics'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Permanently delete a resource topic'

      response(200, 'successful - admin only') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { deleted_resource_topic.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { deleted_resource_topic.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource topic not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end