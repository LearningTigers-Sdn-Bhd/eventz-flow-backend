# visitors_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Visitors', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:staff_user) { create(:user, :staff_member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }

  # --- Setup Event ---
  let!(:organizer_event) do
    event = create(:event, title: 'Organizer Event', payment_status: :paid, use_ticket: false)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  # --- Setup Visitors ---
  let!(:existing_visitor) do
    create(:visitor, event: organizer_event, full_name: 'Existing Visitor', email: 'existing@example.com', phone: '+1234567890')
  end

  let(:valid_visitor_params) do
    {
      visitor: {
        full_name: 'New Visitor',
        email: 'new.visitor@example.com',
        phone: '1234567890',
        gender: 'male',
        age: 30
      }
    }
  end

  path '/v1/events/{event_id}/visitors' do
    parameter name: 'event_id', in: :path, type: :string, description: 'Event ID'

    get 'Lists visitors for an event' do
      tags 'Visitors'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'Visitors retrieved successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }
        let(:event_id) { organizer_event.id }

        run_test!
      end
    end

    post 'Creates a visitor' do
      tags 'Visitors'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :visitor, in: :body, schema: {
        type: :object,
        properties: {
          visitor: {
            type: :object,
            properties: {
              full_name: { type: :string },
              email: { type: :string },
              phone: { type: :string },
              gender: { type: :string },
              age: { type: :integer }
            },
            required: ['full_name']
          }
        }
      }

      response '201', 'Visitor created' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:visitor) { valid_visitor_params[:visitor] }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['full_name']).to eq('New Visitor')
          expect(data['public_id']).to be_present
        end
      end

      response '422', 'Validation error' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:visitor) { { visitor: { full_name: '' } } }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/visitors/{id}' do
    parameter name: 'event_id', in: :path, type: :string, description: 'Event ID'
    parameter name: 'id', in: :path, type: :string, description: 'Visitor public_id or ID'

    get 'Shows a visitor' do
      tags 'Visitors'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'Visitor retrieved' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { existing_visitor.public_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(existing_visitor.id)
        end
      end

      response '404', 'Visitor not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { 'non-existent-id' }

        run_test!
      end
    end

    patch 'Updates a visitor' do
      tags 'Visitors'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :visitor, in: :body, schema: {
        type: :object,
        properties: {
          visitor: {
            type: :object,
            properties: {
              full_name: { type: :string },
              email: { type: :string },
              phone: { type: :string }
            }
          }
        }
      }

      response '200', 'Visitor updated' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { existing_visitor.public_id }
        let(:visitor) { { visitor: { full_name: 'Updated Name' } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['full_name']).to eq('Updated Name')
        end
      end
    end

    delete 'Deletes a visitor' do
      tags 'Visitors'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'Visitor deleted' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }
        let(:id) { existing_visitor.public_id }

        run_test!
      end
    end
  end
end
