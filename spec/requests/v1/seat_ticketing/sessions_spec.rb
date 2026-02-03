require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::Sessions', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event_admin) { create(:user) }
  let(:member) { create(:user, :member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member)[:access_token] }

  let(:event) { create(:event, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  
  let(:session_attr) { attributes_for(:event_seat_session, event_id: event.id) }
  let!(:seat_session) { create(:event_seat_session, event: event) }

  describe 'GET /v1/seat_ticketing/sessions' do
    context 'as authorized user' do
      it 'returns sessions for the event' do
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).size).to eq(1)
      end
    end

    context 'as unauthorized user' do
      it 'returns empty list or forbidden' do
         # Policy scope returns none
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id }, headers: { 'Authorization' => "Bearer #{member_token}" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_empty
      end
    end
  end

  describe 'POST /v1/seat_ticketing/sessions' do
    context 'when authorized' do
      it 'creates a session' do
        post '/v1/seat_ticketing/sessions', params: { session: session_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:created)
      end
    end

    context 'when unauthorized (member)' do
      it 'returns forbidden' do
        post '/v1/seat_ticketing/sessions', params: { session: session_attr }, headers: { 'Authorization' => "Bearer #{member_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when event seat ticketing is disabled' do
      let(:disabled_event) { create(:event, use_seat_ticketing: false) }
      let(:disabled_attr) { attributes_for(:event_seat_session, event_id: disabled_event.id) }
      let!(:admin_assignment) { create(:event_assignment, event: disabled_event, user: event_admin, role: :event_admin) }

      it 'returns forbidden' do
        post '/v1/seat_ticketing/sessions', params: { session: disabled_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/:id' do
    let!(:venue) { create(:event_seat_venue, event_seat_session: seat_session) }
    let!(:section) { create(:event_seat_section, event_seat_venue: venue) }
    let!(:seat) { create(:event_ticket_seat, event_seat_section: section) }

    it 'returns the session with nested venue, sections, and seats' do
      get "/v1/seat_ticketing/sessions/#{seat_session.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['id']).to eq(seat_session.id)
      expect(json['event_seat_venues']).to be_present
      expect(json['event_seat_venues'].first['id']).to eq(venue.id)
      expect(json['event_seat_venues'].first['event_seat_sections']).to be_present
      expect(json['event_seat_venues'].first['event_seat_sections'].first['id']).to eq(section.id)
      expect(json['event_seat_venues'].first['event_seat_sections'].first['event_ticket_seats']).to be_present
      expect(json['event_seat_venues'].first['event_seat_sections'].first['event_ticket_seats'].first['id']).to eq(seat.id)
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/public' do
    let(:public_event) { create(:event, use_seat_ticketing: true) }
    let!(:published_session) { create(:event_seat_session, event: public_event, status: :published) }
    let!(:draft_session) { create(:event_seat_session, event: public_event, status: :draft) }

    it 'returns only published sessions by event slug' do
      get '/v1/seat_ticketing/sessions/public', params: { event_slug: public_event.slug }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first['id']).to eq(published_session.id)
    end

    it 'returns bad request when event_slug is missing' do
      get '/v1/seat_ticketing/sessions/public'

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns not found when event does not exist' do
      get '/v1/seat_ticketing/sessions/public', params: { event_slug: 'missing-event' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/public/:id' do
    let(:public_event) { create(:event, use_seat_ticketing: true) }
    let!(:published_session) { create(:event_seat_session, event: public_event, status: :published) }
    let!(:draft_session) { create(:event_seat_session, event: public_event, status: :draft) }

    it 'returns published session by id' do
      get "/v1/seat_ticketing/sessions/public/#{published_session.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(published_session.id)
    end

    it 'returns published session by slug' do
      get "/v1/seat_ticketing/sessions/public/#{published_session.slug}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(published_session.id)
    end

    it 'returns published session by public_id' do
      get "/v1/seat_ticketing/sessions/public/#{published_session.public_id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(published_session.id)
    end

    it 'returns not found for non-published session' do
      get "/v1/seat_ticketing/sessions/public/#{draft_session.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /v1/seat_ticketing/sessions/:id/bulk_update' do
    let(:bulk_params) do
      {
        session: {
          name: "Updated Blueprint",
          event_seat_venues_attributes: [
            {
              name: "Main Hall",
              total_row: 10,
              total_column: 10,
              event_seat_sections_attributes: [
                {
                  name: "VIP Section",
                  start_row: 1,
                  start_column: 1,
                  seat_row: 5,
                  seat_column: 5,
                  event_ticket_seats_attributes: [
                    {
                      name: "A1",
                      row_set: 1,
                      col_set: 1
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    end

    it 'updates the session and creates nested resources' do
      patch "/v1/seat_ticketing/sessions/#{seat_session.id}/bulk_update", 
            params: bulk_params, 
            headers: { 'Authorization' => "Bearer #{event_admin_token}" }
            
      expect(response).to have_http_status(:ok)
      
      seat_session.reload
      expect(seat_session.name).to eq("Updated Blueprint")
      expect(seat_session.event_seat_venues.count).to eq(1)
      
      venue = seat_session.event_seat_venues.first
      expect(venue.name).to eq("Main Hall")
      expect(venue.event_seat_sections.count).to eq(1)
      
      section = venue.event_seat_sections.first
      expect(section.name).to eq("VIP Section")
      expect(section.event_ticket_seats.count).to eq(1)
      
      seat = section.event_ticket_seats.first
      expect(seat.name).to eq("A1")
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
    it 'archives the session (soft delete)' do
      delete "/v1/seat_ticketing/sessions/#{seat_session.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(seat_session.reload.deleted_at).not_to be_nil
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:id/force_delete' do
    it 'deletes the session' do
      delete "/v1/seat_ticketing/sessions/#{seat_session.id}/force_delete", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(EventSeatSession.find_by(id: seat_session.id)).to be_nil
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/:id/archive' do
     # Route is defined as: delete :archive in some places? No, check controller
     # Controller: def archive ... @session.archive ... head :no_content
     # Route: In routes.rb: resources :sessions do member do delete :force_delete; patch :restore; end; end
     # Wait, I didn't add :archive route in routes.rb! I only added force_delete and restore.
     # Controller has `archive` method but routes.rb has `resources :sessions`. Rails resources includes DELETE which maps to destroy action.
     # But existing `Event` controller has `delete :archive`? No, existing event controller uses destroy to archive.
     # Let's check my SessionsController code. 
     # `def archive`... `def force_delete`.
     # Standard `destroy` usually maps to DELETE /sessions/:id.
     # In my `SessionsController`, I didn't define `destroy` method! I defined `archive` method but not mapped?
     # Wait, `resources :sessions` maps DELETE /id to `destroy` action.
     # I should rename `archive` to `destroy` in controller to match `resources` default, OR add route.
     # Let me check `SessionsController` content again.
  end
end
