require 'rails_helper'

RSpec.describe 'V1::LuckyDraw scanned_only participant pool', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }

  let!(:scanned) { create(:ticket, event: event, ticket_type: ticket_type, attendee_name: 'Scanned', checked_in: true) }
  let!(:unscanned) { create(:ticket, event: event, ticket_type: ticket_type, attendee_name: 'Unscanned', checked_in: false) }

  def pool_names(session)
    get "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}/participants", headers: headers
    expect(response).to have_http_status(:ok)
    (JSON.parse(response.body)['data'] || []).map { |p| p['name'] }
  end

  it 'returns every ticket when scanned_only is off' do
    session = create(:lucky_draw_session, event: event, created_by: org_owner)
    expect(pool_names(session)).to contain_exactly('Scanned', 'Unscanned')
  end

  it 'returns only checked-in tickets when scanned_only is on' do
    session = create(:lucky_draw_session, event: event, created_by: org_owner, scanned_only: true)
    expect(pool_names(session)).to contain_exactly('Scanned')
  end

  it 'persists scanned_only through create and update' do
    post "/v1/events/#{event.id}/lucky_draw/sessions",
         params: { title: 'S', draw_styles: { style: 'wheel', theme: 'wireframe' }, scanned_only: true },
         headers: headers
    expect(response).to have_http_status(:created)
    data = JSON.parse(response.body)['data']
    expect(data['scanned_only']).to be true

    put "/v1/events/#{event.id}/lucky_draw/sessions/#{data['id']}", params: { scanned_only: false }, headers: headers
    expect(JSON.parse(response.body)['data']['scanned_only']).to be false
  end

  describe 'day range' do
    let(:d1) { Time.zone.local(2026, 10, 6, 10) }
    let(:d2) { Time.zone.local(2026, 10, 7, 10) }
    let(:d3) { Time.zone.local(2026, 10, 8, 23, 30) }

    def make_ticket(name, at)
      create(:ticket, event: event, ticket_type: ticket_type, attendee_name: name, checked_in: true, check_in_at: at)
    end

    let!(:dayone) { make_ticket('Dayone', d1) }
    let!(:daytwo) { make_ticket('Daytwo', d2) }
    let!(:latethree) { make_ticket('Latethree', d3) }

    def range_pool(from, to)
      session = create(:lucky_draw_session, event: event, created_by: org_owner, scanned_only: true,
                                            scanned_from: from, scanned_to: to)
      pool_names(session) - %w[Scanned Unscanned]
    end

    it 'keeps anyone checked in on any day when no range is set' do
      expect(range_pool(nil, nil)).to contain_exactly('Dayone', 'Daytwo', 'Latethree')
    end

    it 'limits to a single day (from == to), including late-evening check-ins' do
      expect(range_pool(Date.new(2026, 10, 7), Date.new(2026, 10, 7))).to contain_exactly('Daytwo')
      expect(range_pool(Date.new(2026, 10, 8), Date.new(2026, 10, 8))).to contain_exactly('Latethree')
    end

    it 'supports a multi-day range and open-ended bounds' do
      expect(range_pool(Date.new(2026, 10, 7), Date.new(2026, 10, 8))).to contain_exactly('Daytwo', 'Latethree')
      expect(range_pool(Date.new(2026, 10, 7), nil)).to contain_exactly('Daytwo', 'Latethree')
      expect(range_pool(nil, Date.new(2026, 10, 6))).to contain_exactly('Dayone')
    end

    context 'with scanned_source scan_log' do
      def scan(ticket, at, source: :staff_scan)
        ScanLog.create!(event: event, scannable: ticket, scanned_at: at, source: source)
      end

      def log_pool(from, to)
        session = create(:lucky_draw_session, event: event, created_by: org_owner, scanned_only: true,
                                              scanned_source: 'scan_log', scanned_from: from, scanned_to: to)
        pool_names(session) - %w[Scanned Unscanned]
      end

      before do
        scan(dayone, d1)
        scan(daytwo, d2)
        scan(dayone, d2) # came back on day 2: first check-in is day 1, but scanned again
        scan(latethree, d3, source: :reprint)
      end

      it 'counts every scan in the range, not just the first check-in' do
        expect(log_pool(Date.new(2026, 10, 7), Date.new(2026, 10, 7))).to contain_exactly('Dayone', 'Daytwo')
      end

      it 'ignores reprints and tickets with no scan log' do
        expect(log_pool(Date.new(2026, 10, 8), Date.new(2026, 10, 8))).to be_empty
      end

      it 'still returns every checked-in ticket when no range is set' do
        expect(log_pool(nil, nil)).to contain_exactly('Dayone', 'Daytwo', 'Latethree')
      end
    end

    it 'rejects an unknown scanned_source' do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: 'Bad', draw_styles: { style: 'wheel', theme: 'wireframe' }, scanned_source: 'nope' },
           headers: headers
      expect(response.status).to be >= 400
    end

    it 'rejects a range that ends before it starts' do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: 'Bad', draw_styles: { style: 'wheel', theme: 'wireframe' },
                     scanned_only: true, scanned_from: '2026-10-08', scanned_to: '2026-10-06' },
           headers: headers
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:unprocessable_entity)
    end

    it 'persists the range and clears it with blank values' do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: 'R', draw_styles: { style: 'wheel', theme: 'wireframe' },
                     scanned_only: true, scanned_from: '2026-10-07', scanned_to: '2026-10-08' },
           headers: headers
      data = JSON.parse(response.body)['data']
      expect([data['scanned_from'], data['scanned_to']]).to eq(%w[2026-10-07 2026-10-08])

      put "/v1/events/#{event.id}/lucky_draw/sessions/#{data['id']}", params: { scanned_from: '', scanned_to: '' }, headers: headers
      data = JSON.parse(response.body)['data']
      expect([data['scanned_from'], data['scanned_to']]).to eq([nil, nil])
    end
  end
end
