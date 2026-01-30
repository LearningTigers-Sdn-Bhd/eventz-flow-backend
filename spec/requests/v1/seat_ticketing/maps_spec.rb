require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::Venues', type: :request do
  let(:event_admin) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }

  let(:event) { create(:event, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  let(:session) { create(:event_seat_session, event: event) }
  let(:venue_attr) { attributes_for(:event_seat_venue) }
  let!(:venue) { create(:event_seat_venue, event_seat_session: session) }

  describe 'GET /v1/seat_ticketing/sessions/:session_id/venues' do
    it 'returns venues for the session' do
      get "/v1/seat_ticketing/sessions/#{session.id}/venues", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  describe 'POST /v1/seat_ticketing/sessions/:session_id/venues' do
    it 'creates a venue' do
      post "/v1/seat_ticketing/sessions/#{session.id}/venues", params: { venue: venue_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PUT /v1/seat_ticketing/sessions/:session_id/venues/:id' do
    it 'updates the venue' do
      put "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}", params: { venue: { name: 'Updated Venue' } }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(venue.reload.name).to eq('Updated Venue')
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:session_id/venues/:id' do
    it 'deletes the venue' do
      delete "/v1/seat_ticketing/sessions/#{session.id}/venues/#{venue.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(EventSeatVenue.find_by(id: venue.id)).to be_nil
    end
  end
end
