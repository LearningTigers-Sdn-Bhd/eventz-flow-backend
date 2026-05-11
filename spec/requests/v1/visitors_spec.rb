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
    create(:visitor, event: organizer_event, full_name: 'Existing Visitor', email: 'existing@example.com',
                     phone: '+1234567890')
  end

  let(:valid_visitor_params) do
    {
      visitor: {
        full_name: 'New Visitor',
        email: 'new.visitor@example.com',
        phone: '1234567890',
        gender: 'male',
        age: 30,
        custom_fields_data: { 'Role' => 'Speaker', 'Company' => 'Acme Inc' }
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
              age: { type: :integer },
              custom_fields_data: { type: :object }
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
          expect(data['custom_fields_data']).to include('Role' => 'Speaker')
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
              phone: { type: :string },
              custom_fields_data: { type: :object }
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

  describe 'PATCH /v1/visitors/:id/unscan' do
    let!(:scanned_visitor) do
      create(
        :visitor,
        event: organizer_event,
        full_name: 'Scanned Visitor',
        checked_in: true,
        check_in_at: Time.current,
        scanned_by_id: staff_user.id
      )
    end

    it 'allows org owners to unscan a checked-in visitor' do
      patch "/v1/visitors/#{scanned_visitor.public_id}/unscan",
            headers: { 'Authorization' => "Bearer #{org_owner_token}" }

      expect(response).to have_http_status(:ok)

      scanned_visitor.reload
      expect(scanned_visitor.checked_in).to be false
      expect(scanned_visitor.check_in_at).to be_nil
      expect(scanned_visitor.scanned_by_id).to be_nil

      json = JSON.parse(response.body)
      expect(json['message']).to eq('Visitor successfully unscanned')
      expect(json.dig('visitor', 'id')).to eq(scanned_visitor.id)
    end

    it 'allows org owners to unscan a checked-in visitor with legacy invalid contact data' do
      scanned_visitor.update_columns(email: 'invalid email', phone: 'invalid phone')

      patch "/v1/visitors/#{scanned_visitor.public_id}/unscan",
            headers: { 'Authorization' => "Bearer #{org_owner_token}" }

      expect(response).to have_http_status(:ok)

      scanned_visitor.reload
      expect(scanned_visitor.checked_in).to be false
      expect(scanned_visitor.check_in_at).to be_nil
      expect(scanned_visitor.scanned_by_id).to be_nil
    end

    it 'returns 422 when the visitor is not checked in' do
      existing_visitor.update_columns(checked_in: false, check_in_at: nil, scanned_by_id: nil)

      patch "/v1/visitors/#{existing_visitor.public_id}/unscan",
            headers: { 'Authorization' => "Bearer #{org_owner_token}" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('Visitor is not checked in')
    end

    it 'forbids non org owners from unscanning visitors' do
      patch "/v1/visitors/#{scanned_visitor.public_id}/unscan",
            headers: { 'Authorization' => "Bearer #{organizer_token}" }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to eq('Only organization owners can unscan visitors')
    end

    it 'returns 404 when the visitor cannot be found' do
      patch '/v1/visitors/00000000-0000-0000-0000-000000000000/unscan',
            headers: { 'Authorization' => "Bearer #{org_owner_token}" }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Visitor not found')
    end
  end
end
