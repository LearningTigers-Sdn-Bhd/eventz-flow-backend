require 'swagger_helper'

RSpec.describe 'V1::ExhibitionContractors', type: :request do
  path '/v1/exhibition_contractors' do
    get('list exhibition_contractors') do
      tags 'Exhibition Contractors'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }

        before do
          create(:user, :exhibition_contractor)
        end

        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post('create exhibition_contractor') do
      tags 'Exhibition Contractors'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :exhibition_contractor, in: :body, schema: {
        type: :object,
        properties: {
          full_name: { type: :string },
          email: { type: :string },
          phone: { type: :string },
          password: { type: :string },
          password_confirmation: { type: :string },
          exhibition_contractor_profile_attributes: {
            type: :object,
            properties: {
              company_name: { type: :string },
              contact_person: { type: :string },
              contact_email: { type: :string },
              contact_phone: { type: :string }
            },
            required: %w[company_name contact_person contact_email contact_phone]
          }
        },
        required: %w[full_name email password password_confirmation]
      }

      response(201, 'created') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:exhibition_contractor) do
          {
            full_name: 'John Doe',
            email: 'john@example.com',
            phone: '1234567890',
            password: 'password123',
            password_confirmation: 'password123',
            exhibition_contractor_profile_attributes: {
              company_name: 'Doe Exhibitions',
              contact_person: 'John Doe',
              contact_email: 'john@doe.com',
              contact_phone: '0987654321'
            }
          }
        end

        run_test!
      end

      response(422, 'unprocessable entity') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:exhibition_contractor) { { full_name: '' } }
        run_test!
      end
    end
  end

  path '/v1/exhibition_contractors/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show exhibition_contractor') do
      tags 'Exhibition Contractors'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
        let(:id) { contractor.id }

        run_test!
      end
    end

    patch('update exhibition_contractor') do
      tags 'Exhibition Contractors'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :exhibition_contractor, in: :body, schema: {
        type: :object,
        properties: {
          full_name: { type: :string },
          email: { type: :string },
          phone: { type: :string },
          exhibition_contractor_profile_attributes: {
            type: :object,
            properties: {
              company_name: { type: :string }
            }
          }
        }
      }

      response(200, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
        let(:id) { contractor.id }
        let(:exhibition_contractor) { { full_name: 'Updated Name' } }

        run_test!
      end
    end

    delete('delete exhibition_contractor') do
      tags 'Exhibition Contractors'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
        let(:id) { contractor.id }

        run_test!
      end
    end
  end

  path '/v1/exhibition_contractors/{id}/toggle_status' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    patch('toggle_status exhibition_contractor') do
      tags 'Exhibition Contractors'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :status_params, in: :body, schema: {
        type: :object,
        properties: {
          status: { type: :string, enum: ['active', 'inactive'] }
        },
        required: %w[status]
      }

      response(200, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
        let(:id) { contractor.id }
        let(:status_params) { { status: 'inactive' } }

        run_test!
      end
    end
  end

  path '/v1/exhibition_contractors/{id}/assigned_events' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('list assigned events') do
      tags 'Exhibition Contractors'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:contractor) { create(:user, :exhibition_contractor, with_profile: true) }
        let(:Authorization) { "Bearer #{jwt_token(contractor)}" }
        let(:id) { contractor.id }

        run_test!
      end
    end
  end
end
