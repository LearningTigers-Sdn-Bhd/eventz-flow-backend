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
      total_leads: { type: :integer, example: 150 },
      leads_this_month: { type: :integer, example: 25 },
      leads_this_week: { type: :integer, example: 8 },
      top_countries: {
        type: :array,
        items: {
          type: :object,
          properties: {
            country: { type: :string, example: 'United States' },
            count: { type: :integer, example: 75 }
          }
        }
      },
      top_companies: {
        type: :array,
        items: {
          type: :object,
          properties: {
            company_name: { type: :string, example: 'Acme Corporation' },
            count: { type: :integer, example: 5 }
          }
        }
      }
    }
  }.freeze

  # ============================================================
  # Test Users and Setup
  # ============================================================
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let(:visitor) { create(:user, role: :member) }
  let!(:resource_lead) { create(:resource_lead, email: 'test@example.com', name: 'Test Lead') }

  # ============================================================
  # API Endpoints
  # ============================================================

  path '/v1/resources/leads' do
    get('list resource leads') do
      tags 'Resources CMS - Leads'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: List all resource leads with contact information'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => {
              type: :array,
              items: RESOURCE_LEAD_SCHEMA
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

        let(:lead_params) { { lead: { 
          email: 'newlead@example.com', 
          name: 'New Lead',
          company_name: 'New Company',
          job_title: 'Event Planner'
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

        let(:lead_params) { { lead: { email: nil, name: nil } } }
        run_test!
      end
    end
  end

  path '/v1/resources/leads/metrics' do
    get('resource leads metrics') do
      tags 'Resources CMS - Leads'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Admin only: Get analytics and metrics for lead generation'

      response(200, 'successful - admin only') do
        schema SharedSchemas::SUCCESS_RESPONSE_SCHEMA.merge(
          'properties' => {
            'data' => LEAD_METRICS_SCHEMA
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