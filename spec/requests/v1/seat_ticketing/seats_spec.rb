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
    it 'returns ticket seats for the section even without authentication when published' do
      session.update(status: :published)
      get "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.first['status']).to eq('available')
    end

    it 'returns forbidden for draft session without authentication' do
      session.update(status: :draft)
      get "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats/:id' do
    it 'returns the ticket seat without authentication' do
      get "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('available')
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats/:id/lock' do
    context 'when session is published' do
      before { session.update(status: :published) }

      it 'locks the seat even without authentication' do
        uuid = SecureRandom.uuid
        post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}/lock", params: { checkout_session_uuid: uuid }
        expect(response).to have_http_status(:ok)
        expect(seat.reload.locked_by_session_id).to eq(uuid)
        expect(seat.status).to eq('locked')
      end

      it 'returns conflict if already locked' do
        existing_checkout = EventSeatCheckoutSession.create!(id: SecureRandom.uuid, event_seat_session: session)
        seat.update(locked_by_session_id: existing_checkout.id)
        post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}/lock", params: { checkout_session_uuid: SecureRandom.uuid }
        expect(response).to have_http_status(:conflict)
      end
    end

    context 'when session is draft' do
      before { session.update(status: :draft) }

      it 'returns forbidden' do
        post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}/lock"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:section_id/ticket-seats/:id/unlock' do
    before { session.update(status: :published) }

    it 'unlocks the seat even without authentication' do
      checkout_session = EventSeatCheckoutSession.create!(id: SecureRandom.uuid, event_seat_session: session)
      seat.update(locked_by_session_id: checkout_session.id)
      post "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}/sections/#{section.id}/ticket-seats/#{seat.id}/unlock", params: { checkout_session_uuid: checkout_session.id }
      expect(response).to have_http_status(:ok)
      expect(seat.reload.locked_by_session_id).to be_nil
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
