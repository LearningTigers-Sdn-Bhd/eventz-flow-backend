require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::PublicSessions', type: :request do
  let(:event) { create(:event, use_seat_ticketing: true, slug: 'test-event') }
  let!(:seat_session) { create(:event_seat_session, event: event, status: :published, location: nil) }
  let!(:venue) { create(:event_seat_venue, event_seat_session: seat_session) }
  let!(:section) { create(:event_seat_section, event_seat_venue: venue) }
  let!(:seat) { create(:event_ticket_seat, event_seat_section: section, row_set: 1, col_set: 1) }

  describe 'GET /v1/seat_ticketing/public_sessions' do
    it 'returns published sessions for the event slug' do
      get '/v1/seat_ticketing/public_sessions', params: { event_slug: event.slug }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first['id']).to eq(seat_session.id)
    end

    it 'returns error when event_slug is missing' do
      get '/v1/seat_ticketing/public_sessions'
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error when event not found' do
      get '/v1/seat_ticketing/public_sessions', params: { event_slug: 'invalid' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /v1/seat_ticketing/public_sessions/:id' do
    it 'returns the diet session payload (no individual seats)' do
      get "/v1/seat_ticketing/public_sessions/#{seat_session.id}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['id']).to eq(seat_session.id)
      # Should include venues and sections
      expect(json['event_seat_venues']).to be_present
      venue_json = json['event_seat_venues'].first
      expect(venue_json['event_seat_sections']).to be_present
      section_json = venue_json['event_seat_sections'].first
      
      # Diet Payload: Individual seats MUST be nil
      expect(section_json['event_ticket_seats']).to be_nil
      
      # Should include seat counts
      counts = event.use_ticket ? section_json['ticket_seat_counts'] : section_json['visitor_seat_counts']
      expect(counts).to be_present
      expect(counts['total']).to eq(1)
      expect(counts['available']).to eq(1)
    end

    it 'works with slug or public_id' do
      get "/v1/seat_ticketing/public_sessions/#{seat_session.slug}"
      expect(response).to have_http_status(:ok)
      
      get "/v1/seat_ticketing/public_sessions/#{seat_session.public_id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns not found for unpublished sessions' do
      seat_session.update(status: :draft)
      get "/v1/seat_ticketing/public_sessions/#{seat_session.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /v1/seat_ticketing/public_sessions/:id/section_seats' do
    it 'returns seats for the specified section' do
      get "/v1/seat_ticketing/public_sessions/#{seat_session.id}/section_seats", params: { section_id: section.id }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['section_id']).to eq(section.id)
      expect(json['seats']).not_to be_empty
      expect(json['seats'].first['id']).to eq(seat.id)
      expect(json['seats'].first['status']).to eq('available')
    end

    it 'returns error for invalid section_id' do
      get "/v1/seat_ticketing/public_sessions/#{seat_session.id}/section_seats", params: { section_id: 0 }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns error if session is not published' do
      seat_session.update(status: :draft)
      get "/v1/seat_ticketing/public_sessions/#{seat_session.id}/section_seats", params: { section_id: section.id }
      expect(response).to have_http_status(:not_found)
    end
  end
end
