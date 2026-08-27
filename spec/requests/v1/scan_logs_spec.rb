require 'rails_helper'

RSpec.describe 'V1::ScanLogs', type: :request do
  let(:event) { create(:event, multiple_scans: true, multiple_scan_mode: :unlimited) }
  let(:owner) { create(:user, :org_owner) }
  let(:owner_token) { JwtService.generate_tokens(owner)[:access_token] }
  let(:headers) { { 'Authorization' => "Bearer #{owner_token}" } }
  let(:main_hall) { create(:event_location, event: event, name: 'Main Hall') }
  let(:ticket) { create(:ticket, event: event, attendee_name: 'Siti') }

  describe 'GET /v1/events/:event_id/scan_logs' do
    it 'returns rows newest first with attendee and location details' do
      create(:scan_log, event: event, scannable: ticket, scanned_at: 2.hours.ago,
                        event_location: main_hall, scanned_by: owner)
      create(:scan_log, event: event, scannable: ticket, scanned_at: 1.hour.ago,
                        event_location: main_hall, scanned_by: owner)

      get "/v1/events/#{event.id}/scan_logs", headers: headers

      expect(response).to have_http_status(:ok)
      rows = JSON.parse(response.body)['data']
      expect(rows.length).to eq(2)
      expect(rows.first['name']).to eq('Siti')
      expect(rows.first['location_name']).to eq('Main Hall')
      expect(rows.first['scanned_by_name']).to eq(owner.full_name)
      expect(Time.parse(rows.first['scanned_at'])).to be > Time.parse(rows.second['scanned_at'])
      expect(JSON.parse(response.body)['pagination']['total_count']).to eq(2)
    end

    it 'filters to a single scannable for the drill-down' do
      other = create(:ticket, event: event, attendee_name: 'Ahmad')
      create(:scan_log, event: event, scannable: ticket)
      create(:scan_log, event: event, scannable: other)

      get "/v1/events/#{event.id}/scan_logs",
          params: { scannable_type: 'Ticket', scannable_id: ticket.id }, headers: headers

      expect(JSON.parse(response.body)['data'].map { |row| row['name'] }).to eq(['Siti'])
    end

    it 'filters by location and by date' do
      create(:scan_log, event: event, scannable: ticket, event_location: main_hall,
                        scanned_at: Time.zone.now.change(hour: 9))
      create(:scan_log, event: event, scannable: ticket, event_location: nil, scanned_at: 3.days.ago)

      get "/v1/events/#{event.id}/scan_logs",
          params: { event_location_id: main_hall.id }, headers: headers
      expect(JSON.parse(response.body)['data'].length).to eq(1)

      get "/v1/events/#{event.id}/scan_logs",
          params: { date: 3.days.ago.to_date.to_s }, headers: headers
      expect(JSON.parse(response.body)['data'].length).to eq(1)
    end

    it 'searches by attendee name' do
      create(:scan_log, event: event, scannable: ticket)
      create(:scan_log, event: event, scannable: create(:ticket, event: event, attendee_name: 'Ahmad'))

      get "/v1/events/#{event.id}/scan_logs", params: { q: 'ahm' }, headers: headers

      expect(JSON.parse(response.body)['data'].map { |row| row['name'] }).to eq(['Ahmad'])
    end

    it 'rejects a user with no access to the event' do
      outsider = create(:user, :member)

      get "/v1/events/#{event.id}/scan_logs",
          headers: { 'Authorization' => "Bearer #{JwtService.generate_tokens(outsider)[:access_token]}" }

      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end
  end
end
