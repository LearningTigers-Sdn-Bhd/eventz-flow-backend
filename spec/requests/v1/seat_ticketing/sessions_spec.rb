require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::Sessions', type: :request do
  let(:event_admin) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }
  let(:member) { create(:user, :member) }
  let(:member_token) { JwtService.generate_tokens(member)[:access_token] }

  let(:event) { create(:event, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  
  let(:session_attr) { attributes_for(:event_seat_session, event_id: event.id) }
  # Use location: nil to avoid auto-creating venues in tests where we want manual control
  let!(:seat_session) { create(:event_seat_session, event: event, location: nil) }

  describe 'GET /v1/seat_ticketing/sessions' do
    context 'as authorized user' do
      it 'returns sessions for the event' do
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['archived']).to be false
      end

      it 'returns archived sessions when archived=true' do
        seat_session.archive
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id, archived: 'true' }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['archived']).to be true
      end

      it 'returns all sessions when full=true' do
        archived_session = create(:event_seat_session, event: event, location: nil)
        archived_session.archive
        
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id, full: 'true' }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(2)
      end
    end

    context 'as unauthorized user' do
      it 'returns empty list' do
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id }, headers: { 'Authorization' => "Bearer #{member_token}" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_empty
      end
    end
  end

  describe 'POST /v1/seat_ticketing/sessions' do
    it 'creates a session' do
      post '/v1/seat_ticketing/sessions', params: { session: session_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:created)
    end

    it 'returns forbidden when unauthorized' do
      post '/v1/seat_ticketing/sessions', params: { session: session_attr }, headers: { 'Authorization' => "Bearer #{member_token}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/:id' do
    it 'returns the session with nested details' do
      venue = create(:event_seat_venue, event_seat_session: seat_session)
      section = create(:event_seat_section, event_seat_venue: venue)
      create(:event_ticket_seat, event_seat_section: section)

      get "/v1/seat_ticketing/sessions/#{seat_session.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(seat_session.id)
      expect(json['event_seat_venues']).not_to be_empty
      expect(json['event_seat_venues'].first['event_seat_sections']).not_to be_empty
      expect(json['event_seat_venues'].first['event_seat_sections'].first['event_ticket_seats']).not_to be_empty
      expect(json['event_seat_venues'].first['event_seat_sections'].first['event_ticket_seats'].first['status']).to eq('available')
    end
  end

  describe 'PUT /v1/seat_ticketing/sessions/:id' do
    it 'updates the session' do
      put "/v1/seat_ticketing/sessions/#{seat_session.id}", params: { session: { name: 'Updated Name' } }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(seat_session.reload.name).to eq('Updated Name')
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:id' do
    it 'archives the session' do
      delete "/v1/seat_ticketing/sessions/#{seat_session.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(seat_session.reload.deleted_at).not_to be_nil
    end
  end

  describe 'PATCH /v1/seat_ticketing/sessions/:id/restore' do
    it 'restores an archived session' do
      seat_session.archive
      patch "/v1/seat_ticketing/sessions/#{seat_session.id}/restore", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(seat_session.reload.deleted_at).to be_nil
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:id/force_delete' do
    it 'permanently deletes the session' do
      delete "/v1/seat_ticketing/sessions/#{seat_session.id}/force_delete", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(EventSeatSession.with_deleted.find_by(id: seat_session.id)).to be_nil
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:id/duplicate' do
    it 'duplicates the session and its nested resources' do
      venue = create(:event_seat_venue, event_seat_session: seat_session)
      section = create(:event_seat_section, event_seat_venue: venue)
      create(:event_ticket_seat, event_seat_section: section)

      post "/v1/seat_ticketing/sessions/#{seat_session.id}/duplicate", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to include(seat_session.name)
      expect(json['id']).not_to eq(seat_session.id)
      
      new_session = EventSeatSession.find(json['id'])
      expect(new_session.event_seat_venues.count).to eq(seat_session.event_seat_venues.count)
    end
  end

  describe 'PATCH /v1/seat_ticketing/sessions/:id/bulk_update' do
    let(:bulk_params) do
      {
        session: {
          name: "Bulk Updated Session",
          event_seat_venues_attributes: [
            {
              name: "New Venue",
              total_row: 10,
              total_column: 10,
              event_seat_sections_attributes: [
                {
                  name: "New Section",
                  start_row: 1,
                  start_column: 1,
                  seat_row: 5,
                  seat_column: 5,
                  event_ticket_seats_attributes: [
                    { name: "A1", row_set: 1, col_set: 1 }
                  ]
                }
              ]
            }
          ]
        }
      }
    end

    it 'updates session with nested attributes' do
      patch "/v1/seat_ticketing/sessions/#{seat_session.id}/bulk_update", params: bulk_params, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      seat_session.reload
      expect(seat_session.name).to eq("Bulk Updated Session")
      expect(seat_session.event_seat_venues.any? { |v| v.name == "New Venue" }).to be true
    end

    it 'persists groups and seat assignments via bulk update' do
      # 1. Setup: Create a venue, section, and seat
      venue = create(:event_seat_venue, event_seat_session: seat_session)
      section = create(:event_seat_section, event_seat_venue: venue)
      seat = create(:event_ticket_seat, event_seat_section: section)

      # 2. Bulk update payload: Create a group and assign the seat to it
      group_bulk_params = {
        session: {
          event_seat_venues_attributes: [{
            id: venue.id,
            event_seat_sections_attributes: [{
              id: section.id,
              event_seat_groups_attributes: [{
                name: "VIP Group",
                extra_price: 50.0
              }],
              event_ticket_seats_attributes: [{
                id: seat.id,
                # Note: We can't know the group ID yet if creating in same request
                # BUT if we save the group first, we can.
                # Let's test if we can just update an existing group.
              }]
            }]
          }]
        }
      }

      patch "/v1/seat_ticketing/sessions/#{seat_session.id}/bulk_update", 
            params: group_bulk_params, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      
      expect(response).to have_http_status(:ok)
      section.reload
      expect(section.event_seat_groups.count).to eq(1)
      group = section.event_seat_groups.first
      expect(group.name).to eq("VIP Group")

      # 3. Now assign the seat to the created group
      assignment_params = {
        session: {
          event_seat_venues_attributes: [{
            id: venue.id,
            event_seat_sections_attributes: [{
              id: section.id,
              event_ticket_seats_attributes: [{
                id: seat.id,
                event_seat_group_assignment_attributes: {
                  event_seat_group_id: group.id
                }
              }]
            }]
          }]
        }
      }

      patch "/v1/seat_ticketing/sessions/#{seat_session.id}/bulk_update", 
            params: assignment_params, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      
      expect(response).to have_http_status(:ok)
      seat.reload
      expect(seat.event_seat_group).to eq(group)
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/public' do
    it 'returns published sessions by event slug' do
      seat_session.update(status: :published)
      get '/v1/seat_ticketing/sessions/public', params: { event_slug: event.slug }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
    end

    it 'returns bad request if slug is missing' do
      get '/v1/seat_ticketing/sessions/public'
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/public/:id' do
    before { seat_session.update(status: :published) }

    it 'finds session by id' do
      get "/v1/seat_ticketing/sessions/public/#{seat_session.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'finds session by slug' do
      get "/v1/seat_ticketing/sessions/public/#{seat_session.slug}"
      expect(response).to have_http_status(:ok)
    end

    it 'finds session by public_id' do
      get "/v1/seat_ticketing/sessions/public/#{seat_session.public_id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:id/checkout' do
    let!(:venue) { create(:event_seat_venue, event_seat_session: seat_session) }
    let!(:section) { create(:event_seat_section, event_seat_venue: venue) }
    let!(:seat) { create(:event_ticket_seat, event_seat_section: section) }
    let!(:ticket_type) { create(:ticket_type, event: event) }
    let(:checkout_session_uuid) { SecureRandom.uuid }
    let!(:checkout_session) { EventSeatCheckoutSession.create!(id: checkout_session_uuid, event_seat_session: seat_session) }
    
    let(:checkout_params) do
      {
        seat_ids: [seat.id],
        checkout_session_uuid: checkout_session_uuid,
        visitor: { full_name: 'John Doe', email: 'john@example.com', phone: '0123456789' },
        ticket_type_id: ticket_type.id
      }
    end

    before { seat_session.update(status: :published) }

    it 'completes checkout successfully' do
      post "/v1/seat_ticketing/sessions/#{seat_session.id}/checkout", params: checkout_params
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['success']).to be true
      expect(seat.reload.status).to eq('sold')
    end

    it 'returns conflict if seat is already sold' do
      if event.use_ticket?
        seat.update!(ticket: create(:ticket, event: event, ticket_type: ticket_type))
      else
        seat.update!(visitor: create(:visitor, event: event))
      end
      
      post "/v1/seat_ticketing/sessions/#{seat_session.id}/checkout", params: checkout_params
      expect(response).to have_http_status(:conflict)
    end
  end
end
