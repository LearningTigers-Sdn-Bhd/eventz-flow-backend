require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::Sections', type: :request do
  let(:event_admin) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }

  let(:event) { create(:event, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  
  let!(:seat_session) { create(:event_seat_session, event: event, location: nil) }
  let!(:venue) { create(:event_seat_venue, event_seat_session: seat_session) }
  let!(:section) { create(:event_seat_section, event_seat_venue: venue) }
  let!(:seat) { create(:event_ticket_seat, event_seat_section: section) }

  describe 'GET /v1/seat_ticketing/sessions/:session_id/venues/:venue_id/sections/:id/seats' do
    it 'returns the detailed seat data for the section' do
      get "/v1/seat_ticketing/sessions/#{seat_session.id}/venues/#{venue.id}/sections/#{section.id}/seats", 
          headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.size).to eq(1)
      expect(json.first['id']).to eq(seat.id)
      expect(json.first['status']).to eq('available')
    end
  end
end
