require 'swagger_helper'

RSpec.describe 'V1::ResourcesLeads', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  RESOURCE_LEAD_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      email: { type: :string, format: :email, example: 'john.doe@company.com' },
      name: { type: :string, example: 'John Doe' },
      phone: { type: :string, nullable: true, example: '+1234567890' },
      company_name: { type: :string, nullable: true, example: 'Acme Corporation' },
      state: { type: :string, nullable: true, example: 'California' },
      country: { type: :string, nullable: true, example: 'United States' },
      job_title: { type: :string, nullable: true, example: 'Event Manager' },
      ip_address: { type: :string, nullable: true, example: '192.168.1.1' },
      accessed_at: { type: :string, format: :date_time, nullable: true },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id email name]
  }.freeze

  LEAD_METRICS_SCHEMA = {
    type: :object,
    properties: {
      resources: {
        type: :object,
        properties: {
          count: { type: :integer, example: 10 },
          filled: { type: :integer, example: 7 }
        },
        required: %w[count filled]
      },
      total_leads: { type: :integer, example: 150 },
      date: {
        type: :array,
        items: {
          type: :object,
          properties: {
            week: { type: :string, example: '2026-W01' },
            lead_counts: { type: :integer, example: 15 }
          },
          required: %w[week lead_counts]
        }
      },
      country: {
        type: :array,
        items: {
          type: :object,
          properties: {
            name: { type: :string, example: 'United States' },
            count: { type: :integer, example: 45 }
          },
          required: %w[name count]
        }
      },
      job: {
        type: :array,
        items: {
          type: :object,
          properties: {
            title: { type: :string, example: 'Event Manager' },
            count: { type: :integer, example: 20 }
          },
          required: %w[title count]
        }
      }
    },
    required: %w[resources total_leads date country job]
  }.freeze

  # ============================================================
  # Test Users and Setup
  # ============================================================
  let!(:org_owner) { create(:user, role: :org_owner) }
  let!(:writer) { create(:user, role: :member) }
  let!(:visitor) { create(:user, role: :member) }

  # Create test resources
  let!(:gated_resource) { create(:resource, is_gated: true, status: :published, title: 'Gated Resource 1') }
  let!(:gated_resource_2) { create(:resource, is_gated: true, status: :published, title: 'Gated Resource 2') }
  let!(:non_gated_resource) { create(:resource, is_gated: false, status: :published, title: 'Non-Gated Resource') }

  # Create leads for gated resources
  let!(:resource_lead) { create(:resource_lead, email: 'test@example.com', name: 'Test Lead', resource: gated_resource, country: 'United States', job_title: 'Event Manager') }
  let!(:resource_lead_2) { create(:resource_lead, email: 'test2@example.com', name: 'Test Lead 2', resource: gated_resource_2, country: 'Malaysia', job_title: 'Marketing Director') }

  # Create lead for non-gated resource (should be excluded from index)
  let!(:non_gated_lead) { create(:resource_lead, email: 'test3@example.com', name: 'Test Lead 3', resource: non_gated_resource) }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/leads' do
    get('list resource leads') do
      tags 'Resources CMS - Leads'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: List all resource leads for gated resources with pagination'

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => {
              type: :array,
              items: RESOURCE_LEAD_SCHEMA.merge(
                properties: RESOURCE_LEAD_SCHEMA[:properties].merge(
                  resource: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      title: { type: :string },
                      slug: { type: :string }
                    }
                  }
                )
              )
            },
            'pagination' => {
              type: :object,
              properties: {
                current_page: { type: :integer },
                total_pages: { type: :integer },
                total_count: { type: :integer },
                per_page: { type: :integer }
              }
            }
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }

        it 'returns only leads for gated resources' do |example|
          submit_request(example.metadata)

          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)['data']

          # Should return 2 leads (for gated resources), not 3 (excluding non-gated)
          expect(data.length).to eq(2)

          # Verify all leads are for gated resources
          data.each do |lead|
            expect(lead['resource']).to be_present
            resource = Resource.find(lead['resource']['id'])
            expect(resource.is_gated).to be true
          end
        end

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

    post('create resource lead') do
      tags 'Resources CMS - Leads'
      consumes 'application/json'
      produces 'application/json'
      description 'Public: Submit lead information for gated content access'

      parameter name: :lead_params, in: :body, schema: {
        type: :object,
        properties: {
          lead: {
            type: :object,
            properties: {
              email: { type: :string, format: :email, example: 'user@company.com' },
              name: { type: :string, example: 'Jane Smith' },
              phone: { type: :string, nullable: true, example: '+1234567890' },
              company_name: { type: :string, nullable: true, example: 'Tech Corp' },
              state: { type: :string, nullable: true, example: 'New York' },
              country: { type: :string, nullable: true, example: 'United States' },
              job_title: { type: :string, nullable: true, example: 'Marketing Director' }
            },
            required: %w[email name]
          }
        },
        required: %w[lead]
      }

      response(201, 'created - public access') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_LEAD_SCHEMA
          }
        )

        let(:lead_params) { { resource_lead: {
          email: 'newlead@example.com',
          name: 'New Lead',
          company_name: 'New Company',
          job_title: 'Event Planner',
          resource_id: gated_resource.id
        } } }
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

        let(:lead_params) { { resource_lead: { email: nil, name: nil, resource_id: gated_resource.id } } }
        run_test!
      end
    end
  end

  path '/v1/resources/leads/metrics' do
    get('resource leads metrics') do
      tags 'Resources CMS - Leads'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Get analytics and metrics for lead generation including resources stats, weekly trends, and top countries/jobs'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => LEAD_METRICS_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }

        it 'returns correct metrics structure' do |example|
          submit_request(example.metadata)

          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)['data']

          # Check resources metrics
          expect(data['resources']).to be_present
          expect(data['resources']['count']).to eq(2) # 2 gated resources
          expect(data['resources']['filled']).to eq(2) # 2 gated resources with leads

          # Check total leads
          expect(data['total_leads']).to eq(3) # All leads including non-gated

          # Check date array exists
          expect(data['date']).to be_an(Array)

          # Check country array
          expect(data['country']).to be_an(Array)
          expect(data['country'].length).to be > 0

          # Check job array
          expect(data['job']).to be_an(Array)
          expect(data['job'].length).to be > 0
        end

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
  end

  path '/v1/resources/leads/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Lead ID'

    get('show resource lead') do
      tags 'Resources CMS - Leads'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Get details of a specific resource lead'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => RESOURCE_LEAD_SCHEMA
          }
        )

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { resource_lead.id }
        run_test!
      end

      response(403, 'forbidden - non-admin') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Access denied' }
        }

        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { resource_lead.id }
        run_test!
      end

      response(404, 'not found') do
        schema type: :object, properties: {
          success: { type: :boolean, example: false },
          message: { type: :string, example: 'Resource lead not found' }
        }

        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end
