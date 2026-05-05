require 'rails_helper'

RSpec.describe 'V1::TicketTypes API', type: :request do
  # Create test users
  let!(:admin_user) { create(:user, :org_owner) }
  let!(:regular_user) { create(:user, :member) }

  # Create a test event with an owner
  let!(:event_owner) { create(:user, :organizer) }
  let!(:test_event) do
    start_date = Time.zone.parse('2026-08-10 09:00:00')
    end_date = Time.zone.parse('2026-08-11 18:00:00')
    event = create(:event, start_date: start_date, end_date: end_date)
    create(:event_assignment, role: :event_admin, event: event, user: event_owner)
    event
  end

  # JWT tokens for authentication
  let(:admin_token) { JwtService.generate_tokens(admin_user)[:access_token] }
  let(:regular_token) { JwtService.generate_tokens(regular_user)[:access_token] }
  let(:owner_token) { JwtService.generate_tokens(event_owner)[:access_token] }

  # Auth headers
  let(:admin_headers) { { 'Authorization' => "Bearer #{admin_token}" } }
  let(:regular_headers) { { 'Authorization' => "Bearer #{regular_token}" } }
  let(:owner_headers) { { 'Authorization' => "Bearer #{owner_token}" } }

  # ============================================================================
  # GLOBAL TICKET TYPES (event_id is null)
  # ============================================================================
  describe 'Global Ticket Types' do
    let!(:global_ticket_type_1) do
      TicketType.create!(
        name: 'General Admission Template',
        price: 50.00,
        quantity: 100,
        max_per_order: 5,
        status: :published,
        event_id: nil
      )
    end

    let!(:global_ticket_type_2) do
      TicketType.create!(
        name: 'VIP Template',
        price: 200.00,
        quantity: 50,
        max_per_order: 2,
        status: :published,
        event_id: nil
      )
    end

    describe 'GET /v1/ticket_types' do
      context 'when authenticated as admin' do
        it 'returns all global ticket types' do
          get '/v1/ticket_types', headers: admin_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json.size).to eq(2)
          expect(json.map { |tt| tt['name'] }).to contain_exactly(
            'General Admission Template',
            'VIP Template'
          )
          expect(json.all? { |tt| tt['event_id'].nil? }).to be true
        end
      end

      context 'when authenticated as regular user' do
        it 'returns all global ticket types' do
          get '/v1/ticket_types', headers: regular_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json.size).to eq(2)
        end
      end

      context 'when not authenticated' do
        it 'returns unauthorized' do
          get '/v1/ticket_types'

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    describe 'GET /v1/ticket_types/:id' do
      context 'when authenticated' do
        it 'returns the specific global ticket type' do
          get "/v1/ticket_types/#{global_ticket_type_1.id}", headers: admin_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['name']).to eq('General Admission Template')
          expect(json['price']).to eq('50.0')
          expect(json['event_id']).to be_nil
        end
      end

      context 'when ticket type does not exist' do
        it 'returns not found' do
          get '/v1/ticket_types/99999', headers: admin_headers

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Global ticket type not found')
        end
      end
    end

    describe 'POST /v1/ticket_types' do
      let(:valid_params) do
        {
          ticket_type: {
            name: 'Early Bird Template',
            price: 30.00,
            quantity: 200,
            max_per_order: 10,
            status: 'published'
          }
        }
      end

      context 'when authenticated as admin' do
        it 'creates a new global ticket type' do
          expect {
            post '/v1/ticket_types', params: valid_params, headers: admin_headers
          }.to change(TicketType, :count).by(1)

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Early Bird Template')
          expect(json['event_id']).to be_nil
        end
      end

      context 'when authenticated as regular user' do
        it 'returns forbidden' do
          post '/v1/ticket_types', params: valid_params, headers: regular_headers

          expect(response).to have_http_status(:forbidden)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Only admins can create global ticket types')
        end
      end

      context 'with invalid params' do
        it 'returns unprocessable entity' do
          invalid_params = { ticket_type: { name: '', price: -10 } }
          post '/v1/ticket_types', params: invalid_params, headers: admin_headers

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe 'PATCH /v1/ticket_types/:id' do
      let(:update_params) do
        {
          ticket_type: {
            name: 'Updated Template Name',
            price: 75.00
          }
        }
      end

      context 'when authenticated as admin' do
        it 'updates the global ticket type' do
          patch "/v1/ticket_types/#{global_ticket_type_1.id}",
                params: update_params,
                headers: admin_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Updated Template Name')
          expect(json['price']).to eq('75.0')
        end
      end

      context 'when authenticated as regular user' do
        it 'returns forbidden' do
          patch "/v1/ticket_types/#{global_ticket_type_1.id}",
                params: update_params,
                headers: regular_headers

          expect(response).to have_http_status(:forbidden)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Only admins can update global ticket types')
        end
      end
    end

    describe 'DELETE /v1/ticket_types/:id' do
      context 'when authenticated as admin' do
        context 'when no tickets are associated' do
          it 'deletes the global ticket type' do
            expect {
              delete "/v1/ticket_types/#{global_ticket_type_1.id}", headers: admin_headers
            }.to change(TicketType, :count).by(-1)

            expect(response).to have_http_status(:no_content)
          end
        end

        context 'when tickets are associated' do
          let!(:ticket) do
            create(:ticket,
              ticket_type: global_ticket_type_1,
              event: test_event,
              user: regular_user
            )
          end

          it 'returns unprocessable entity' do
            delete "/v1/ticket_types/#{global_ticket_type_1.id}", headers: admin_headers

            expect(response).to have_http_status(:unprocessable_content)
            json = JSON.parse(response.body)
            expect(json['error']).to eq('Cannot delete ticket type with existing tickets')
          end
        end
      end

      context 'when authenticated as regular user' do
        it 'returns forbidden' do
          delete "/v1/ticket_types/#{global_ticket_type_1.id}", headers: regular_headers

          expect(response).to have_http_status(:forbidden)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Only admins can delete global ticket types')
        end
      end
    end
  end

  # ============================================================================
  # EVENT-SPECIFIC TICKET TYPES (event_id is present)
  # ============================================================================
  describe 'Event-Specific Ticket Types' do
    let!(:event_ticket_type) do
      TicketType.create!(
        name: 'Event General Admission',
        price: 60.00,
        quantity: 150,
        max_per_order: 5,
        status: :published,
        event: test_event
      )
    end

    describe 'GET /v1/events/:event_id/ticket_types' do
      context 'when authenticated as event owner' do
        it 'returns all ticket types for the event' do
          get "/v1/events/#{test_event.id}/ticket_types", headers: owner_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json.size).to eq(1)
          expect(json.first['name']).to eq('Event General Admission')
          expect(json.first['event_id']).to eq(test_event.id)
        end
      end
    end

    describe 'GET /v1/events/:event_id/ticket_types/:id' do
      context 'when authenticated as event owner' do
        it 'returns the specific ticket type' do
          get "/v1/events/#{test_event.id}/ticket_types/#{event_ticket_type.id}",
              headers: owner_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Event General Admission')
          expect(json['event_id']).to eq(test_event.id)
        end
      end
    end

    describe 'POST /v1/events/:event_id/ticket_types' do
      let(:valid_params) do
        {
          ticket_type: {
            name: 'Event VIP',
            price: 150.00,
            quantity: 50,
            max_per_order: 2,
            status: 'published',
            valid_day_indexes: [1]
          }
        }
      end

      context 'when authenticated as event owner' do
        it 'creates a new ticket type for the event' do
          expect {
            post "/v1/events/#{test_event.id}/ticket_types",
                 params: valid_params,
                 headers: owner_headers
          }.to change(test_event.ticket_types, :count).by(1)

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Event VIP')
          expect(json['event_id']).to eq(test_event.id)
          expect(json['valid_day_indexes']).to eq([1])
        end
      end

      context 'when authenticated as regular user (not event owner)' do
        it 'returns forbidden' do
          post "/v1/events/#{test_event.id}/ticket_types",
               params: valid_params,
               headers: regular_headers

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'PATCH /v1/events/:event_id/ticket_types/:id' do
      let(:update_params) do
        {
          ticket_type: {
            name: 'Updated Event Ticket',
            price: 80.00,
            valid_day_indexes: [1, 2]
          }
        }
      end

      context 'when authenticated as event owner' do
        it 'updates the ticket type' do
          patch "/v1/events/#{test_event.id}/ticket_types/#{event_ticket_type.id}",
                params: update_params,
                headers: owner_headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Updated Event Ticket')
          expect(json['price']).to eq('80.0')
          expect(json['valid_day_indexes']).to eq([1, 2])
        end
      end

      context 'when authenticated as regular user' do
        it 'returns forbidden' do
          patch "/v1/events/#{test_event.id}/ticket_types/#{event_ticket_type.id}",
                params: update_params,
                headers: regular_headers

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'DELETE /v1/events/:event_id/ticket_types/:id' do
      context 'when authenticated as event owner' do
        context 'when no tickets are associated' do
          it 'deletes the ticket type' do
            expect {
              delete "/v1/events/#{test_event.id}/ticket_types/#{event_ticket_type.id}",
                     headers: owner_headers
            }.to change(test_event.ticket_types, :count).by(-1)

            expect(response).to have_http_status(:no_content)
          end
        end
      end

      context 'when authenticated as regular user' do
        it 'returns forbidden' do
          delete "/v1/events/#{test_event.id}/ticket_types/#{event_ticket_type.id}",
                 headers: regular_headers

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
