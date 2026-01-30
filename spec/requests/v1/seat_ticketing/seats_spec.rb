require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::EventTicketSeats', type: :request do
  let(:event_admin) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }

  let(:event) { create(:event, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  let(:session) { create(:event_seat_session, event: event) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue) }
  let(:seat_attr) { attributes_for(:event_ticket_seat) }
  let!(:seat) { create(:event_ticket_seat, event_seat_section: section) }

  describe 'GET /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats' do
    it 'returns ticket seats for the section' do
      get "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats' do
    it 'creates a ticket seat' do
      post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats", params: { ticket_seat: seat_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PUT /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats/:id' do
    it 'updates the ticket seat' do
      put "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}", params: { ticket_seat: { name: 'A1-Updated' } }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(seat.reload.name).to eq('A1-Updated')
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats/:id' do
    it 'deletes the ticket seat' do
      delete "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(EventTicketSeat.find_by(id: seat.id)).to be_nil
    end
  end
end
