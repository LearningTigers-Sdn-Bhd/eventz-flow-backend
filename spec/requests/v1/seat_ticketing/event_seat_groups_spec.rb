require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::EventSeatGroups', type: :request do
  let(:event_admin) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }
  let(:headers) { { 'Authorization' => "Bearer #{event_admin_token}" } }

  let(:event) { create(:event, use_seat_ticketing: true, use_ticket: true) }
  let!(:assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  let(:session) { create(:event_seat_session, event: event, location: nil) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue) }
  let!(:group) { create(:event_seat_group, event_seat_section: section) }

  describe 'GET /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/groups' do
    it 'returns groups for the section' do
      get "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/groups", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/groups' do
    it 'creates a group and a ticket type' do
      params = { group: { name: 'VIP Row', extra_price: 100.0 } }
      expect {
        post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/groups", params: params, headers: headers
      }.to change(EventSeatGroup, :count).by(1).and change(TicketType, :count).by(1)
      
      expect(response).to have_http_status(:created)
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/groups/:id/assign_seats' do
    let(:seat1) { create(:event_ticket_seat, event_seat_section: section) }
    let(:seat2) { create(:event_ticket_seat, event_seat_section: section) }

    it 'assigns seats to the group and updates ticket quantity' do
      post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/groups/#{group.id}/assign_seats", 
           params: { seat_ids: [seat1.id, seat2.id] }, headers: headers
      
      expect(response).to have_http_status(:ok)
      expect(group.reload.event_ticket_seats.count).to eq(2)
      expect(group.ticket_type.quantity).to eq(2)
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/groups/:id' do
    it 'deletes the group' do
      delete "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(EventSeatGroup.find_by(id: group.id)).to be_nil
    end
  end
end
