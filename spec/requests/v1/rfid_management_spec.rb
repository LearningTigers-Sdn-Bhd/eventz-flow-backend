require 'rails_helper'

# Plan 5 Task 7: the staff API. Signed-in users only, policy-protected, and the
# only place a human can change what a reading means.
RSpec.describe 'V1::Rfid staff API', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:member) { create(:user, :member) }
  let(:event) { create(:event, use_api_access: true) }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:ticket) do
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                       attendee_name: 'Ahmad Bin Ali',
                                       attendee_email: 'ahmad@example.com',
                                       attendee_phone: '0123456789',
                                       check_in_at: Time.zone.parse('2026-09-26T08:00:00Z'))
  end
  let(:tag) { '3412CDAB500104E0' }
  let(:station_key) { 'gate-entry' }
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }
  let(:headers) { auth_headers(owner) }

  def body
    JSON.parse(response.body)
  end

  def device_headers(key)
    { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station_key }
  end

  def bind_via_device(key, at: base - 1.hour, uid: tag)
    post '/v1/rfid/bindings',
         params: { public_id: ticket.public_id, protocol: 'iso15693', uid_raw_hex: uid,
                   mode: 'bind', payload_version: nil, operation_id: SecureRandom.uuid,
                   captured_at: at.iso8601(6), replace: false, reason: nil },
         headers: device_headers(key), as: :json
    expect(response).to have_http_status(:created), response.body
  end

  def observe_via_device(key, items)
    post '/v1/rfid/observations', params: { observations: items }, headers: device_headers(key),
                                  as: :json
    expect(response).to have_http_status(:ok), response.body
    body['results']
  end

  def reading(role, at, uid: tag, delivery: SecureRandom.uuid)
    { 'delivery_id' => delivery, 'role' => role, 'protocol' => 'iso15693', 'uid_raw_hex' => uid,
      'payload_hex' => nil, 'device_direction_raw' => nil, 'device_time_raw_hex' => nil,
      'device_record_seq' => nil, 'flags_raw' => {}, 'captured_at' => at.iso8601(6) }
  end

  let!(:device_key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let!(:gate) { Rfid::Station.create!(event: event, station_key: station_key, kind: 'gate') }

  describe 'authorization' do
    before { bind_via_device(device_key) }

    it 'lets an owner read every staff endpoint' do
      get "/v1/events/#{event.id}/rfid/summary", headers: headers
      expect(response).to have_http_status(:ok)

      %w[stations bindings visits anomalies].each do |path|
        get "/v1/events/#{event.id}/rfid/#{path}", headers: headers
        expect(response).to have_http_status(:ok), path
      end

      get "/v1/events/#{event.id}/rfid/report.xlsx", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'refuses a signed-in user with no access to the event' do
      get "/v1/events/#{event.id}/rfid/summary", headers: auth_headers(member)

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses every API key, rfid or ordinary' do
      ordinary = create(:api_key, user: owner, event: event, scope: 'read_write')

      [device_key, ordinary].each do |key|
        get "/v1/events/#{event.id}/rfid/summary",
            headers: { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station_key }
        expect(response).to have_http_status(:forbidden)

        patch "/v1/events/#{event.id}/rfid/settings", params: { rfid_mode: 'write' },
                                                      headers: { 'Authorization' => key.raw_key }
        expect(response).to have_http_status(:forbidden)
      end

      expect(event.reload.rfid_mode).to eq('bind')
    end

    it 'shows nothing from another event' do
      other_event = create(:event, use_api_access: true)
      other_ticket = create(:ticket, :paid, event: other_event, attendee_name: 'Zara Isolated')

      get "/v1/events/#{event.id}/rfid/bindings", headers: headers
      expect(body['bindings'].map { |row| row['ticket_public_id'] }).to eq([ticket.public_id])
      expect(body['pagination']['total_count']).to eq(1)

      get "/v1/events/#{event.id}/rfid/visits", headers: headers
      expect(response.body).not_to include('Zara Isolated')
      expect(other_ticket.event_id).to eq(other_event.id)
    end
  end

  describe 'GET summary' do
    before { bind_via_device(device_key) }

    it 'counts attendance, visits still open and anomalies' do
      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 30.minutes)])
      observe_via_device(device_key, [reading('entry', base + 1.hour)])

      get "/v1/events/#{event.id}/rfid/summary", headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['headcount']).to eq(1)
      expect(body['open_visits']).to eq(1)
      expect(body['anomaly_count']).to eq(0)
      expect(Time.iso8601(body['last_observed_at'])).to eq(base + 1.hour)
    end

    it 'narrows the attendance figures to one ticket type' do
      vip = create(:ticket_type, event: event, name: 'VIP')
      create(:ticket, :paid, :checked_in, event: event, ticket_type: vip, attendee_name: 'Vip Guest',
                                          check_in_at: base)
      observe_via_device(device_key, [reading('entry', base)])

      get "/v1/events/#{event.id}/rfid/summary", params: { ticket_type_id: vip.id }, headers: headers

      expect(body).to include('registered' => 1, 'checked_in' => 1, 'inside' => 0, 'outside' => 0)
      expect(body['missed_scans']).to eq('no_tag' => 1, 'no_read' => 0)
      expect(body['ticket_types'].map { |type| type['name'] }).to include('Delegate', 'VIP')

      get "/v1/events/#{event.id}/rfid/summary", params: { ticket_type_id: ticket_type.id }, headers: headers
      expect(body).to include('registered' => 1, 'inside' => 1)
    end

    it 'counts a corrected reading and a visit anomaly' do
      observe_via_device(device_key, [reading('exit', base)])

      get "/v1/events/#{event.id}/rfid/summary", headers: headers

      expect(body['anomaly_count']).to eq(1)
      expect(body['open_visits']).to eq(0)
      expect(body['headcount']).to eq(0)
    end
  end

  describe 'GET bindings filters' do
    before { bind_via_device(device_key) }

    it 'pages, searches and filters bindings instead of returning them all' do
      other = create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                                  attendee_name: 'Siti Nurhaliza', check_in_at: base)
      post '/v1/rfid/bindings',
           params: { public_id: other.public_id, protocol: 'iso15693', uid_raw_hex: 'AABBCCDD00112233',
                     mode: 'bind', payload_version: nil, operation_id: SecureRandom.uuid,
                     captured_at: (base - 30.minutes).iso8601(6), replace: false, reason: nil },
           headers: device_headers(device_key), as: :json
      expect(response).to have_http_status(:created)
      event.rfid_bindings.find_by(ticket_id: other.id).update!(revoked_at: Time.current)

      get "/v1/events/#{event.id}/rfid/bindings", params: { per_page: 1 }, headers: headers
      expect(body['bindings'].length).to eq(1)
      expect(body['pagination']).to include('total_count' => 2, 'total_pages' => 2)

      get "/v1/events/#{event.id}/rfid/bindings", params: { q: 'siti' }, headers: headers
      expect(body['bindings'].map { |row| row['ticket_name'] }).to eq(['Siti Nurhaliza'])

      get "/v1/events/#{event.id}/rfid/bindings", params: { q: 'aabbccdd' }, headers: headers
      expect(body['bindings'].length).to eq(1)

      get "/v1/events/#{event.id}/rfid/bindings", params: { status: 'active' }, headers: headers
      expect(body['bindings'].map { |row| row['ticket_name'] }).to eq(['Ahmad Bin Ali'])
      expect(body['bindings'].first['ticket_type']).to eq('Delegate')

      get "/v1/events/#{event.id}/rfid/bindings", params: { status: 'revoked' }, headers: headers
      expect(body['bindings'].length).to eq(1)

      get "/v1/events/#{event.id}/rfid/bindings", params: { status: 'bogus' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET display_activity' do
    before { bind_via_device(device_key) }

    it 'defaults to entries and returns both directions in occurrence order' do
      observe_via_device(device_key, [reading('entry', base), reading('entry', base + 1.minute),
                                      reading('exit', base + 30.minutes), reading('entry', base + 1.hour)])
      get "/v1/events/#{event.id}/rfid/display_activity", headers: headers
      expect(response).to have_http_status(:ok)
      expect(body['activity'].map { |row| row['direction'] }).to eq(%w[in in])

      get "/v1/events/#{event.id}/rfid/display_activity", params: { mode: 'both' }, headers: headers
      expect(body['activity'].map { |row| row['direction'] }).to eq(%w[in out in])
      expect(body['activity'].map { |row| Time.iso8601(row['occurred_at']) }).to eq([base + 1.hour, base + 30.minutes, base])
      expect(body['activity'].map { |row| row['id'] }.uniq.length).to eq(3)
      expect(body['activity'].first.keys).to match_array(%w[id ticket_name direction occurred_at])
    end

    it 'shows an accepted physical exit even when its entry scan was missed' do
      observe_via_device(device_key, [reading('exit', base)])
      expect(event.rfid_visits.count).to eq(0)
      get "/v1/events/#{event.id}/rfid/display_activity", params: { mode: 'out' }, headers: headers
      expect(body['activity'].size).to eq(1)
      expect(body['activity'].first).to include('direction' => 'out', 'ticket_name' => 'Ahmad Bin Ali')
      expect(Time.iso8601(body['activity'].first['occurred_at'])).to eq(base)
    end

    it 'finds a recent exit from an old visit even after 40 newer entries' do
      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 3.hours)])
      41.times do |index|
        observation = create(:rfid_observation, event: event, station: gate, outcome: 'accepted')
        Rfid::Visit.create!(event: event, ticket: ticket, ticket_public_id: ticket.public_id, ticket_name: 'Later guest',
                           entry_observation: observation, entry_at: base + (index + 1).minutes)
      end
      get "/v1/events/#{event.id}/rfid/display_activity", params: { mode: 'out' }, headers: headers
      expect(body['activity'].size).to eq(1)
      expect(body['activity'].first).to include('direction' => 'out', 'ticket_name' => 'Ahmad Bin Ali')
      expect(Time.iso8601(body['activity'].first['occurred_at'])).to eq(base + 3.hours)

      get "/v1/events/#{event.id}/rfid/display_activity", params: { mode: 'both' }, headers: headers
      expect(body['activity'].size).to eq(40)
      expect(body['activity'].first['direction']).to eq('out')
    end

    it 'excludes manual closures and data from other events' do
      observe_via_device(device_key, [reading('entry', base)])
      event.rfid_visits.first.update!(exit_at: base + 1.hour, manual: true)
      other = create(:event)
      observation = create(:rfid_observation, event: other)
      Rfid::Visit.create!(event: other, ticket_public_id: SecureRandom.uuid, ticket_name: 'Other event guest', entry_observation: observation, entry_at: base + 2.hours)
      get "/v1/events/#{event.id}/rfid/display_activity", params: { mode: 'out' }, headers: headers
      expect(body['activity']).to eq([])
      get "/v1/events/#{event.id}/rfid/display_activity", params: { mode: 'both' }, headers: headers
      expect(body['activity'].size).to eq(1)
      expect(response.body).not_to include('Other event guest')
    end

    it 'validates the mode and keeps the staff authorization boundary' do
      path = "/v1/events/#{event.id}/rfid/display_activity"
      get path, params: { mode: 'bogus' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      get path, headers: auth_headers(member)
      expect(response).to have_http_status(:forbidden)
      get path, headers: { 'Authorization' => device_key.raw_key }
      expect(response).to have_http_status(:forbidden)
      get path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET guest_visits' do
    before { bind_via_device(device_key) }

    it 'folds a guest\'s in/out visits into one row' do
      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 30.minutes),
                                      reading('entry', base + 1.hour), reading('exit', base + 90.minutes),
                                      reading('entry', base + 2.hours)])

      get "/v1/events/#{event.id}/rfid/guest_visits", headers: headers

      expect(response).to have_http_status(:ok), response.body
      expect(body['guests'].length).to eq(1)
      guest = body['guests'].first
      expect(guest).to include('visit_count' => 3, 'status' => 'inside', 'ticket_name' => 'Ahmad Bin Ali')
      expect(guest['visits'].map { |visit| visit['status'] }).to eq(%w[open closed closed])
      expect(body['pagination']['total_count']).to eq(1)

      get "/v1/events/#{event.id}/rfid/guest_visits", params: { status: 'outside' }, headers: headers
      expect(body['guests']).to eq([])

      get "/v1/events/#{event.id}/rfid/guest_visits", params: { q: 'ahmad' }, headers: headers
      expect(body['guests'].length).to eq(1)

      get "/v1/events/#{event.id}/rfid/guest_visits", params: { ticket_type_id: 0 }, headers: headers
      expect(body['guests']).to eq([])
      expect(body['ticket_types'].map { |type| type['name'] }).to include('Delegate')

      get "/v1/events/#{event.id}/rfid/guest_visits", params: { status: 'bogus' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'anomaly filters' do
    before { bind_via_device(device_key) }

    it 'searches and filters the anomaly list' do
      observe_via_device(device_key, [reading('entry', base, uid: 'FFEEDDCCBBAA9988'),
                                      reading('exit', base + 5.minutes)])

      get "/v1/events/#{event.id}/rfid/anomalies", headers: headers
      total = body['pagination']['total_count']
      expect(total).to be >= 1
      expect(body['stations']).to include(station_key)

      get "/v1/events/#{event.id}/rfid/anomalies", params: { q: 'ffeedd' }, headers: headers
      expect(body['observations'].map { |row| row['tag_key'] }).to eq(['FFEEDDCCBBAA9988'])

      get "/v1/events/#{event.id}/rfid/anomalies", params: { outcome: 'unknown_tag' }, headers: headers
      expect(body['observations'].map { |row| row['current_outcome'] }.uniq).to eq(['unknown_tag'])

      get "/v1/events/#{event.id}/rfid/anomalies", params: { station: 'nope' }, headers: headers
      expect(body['observations']).to eq([])
    end
  end

  describe 'GET missed_scans' do
    before { bind_via_device(device_key) }

    it 'lists desk check-ins no gate has read, filtered by reason' do
      create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                          attendee_name: 'No Sticker',
                                          check_in_at: base)

      get "/v1/events/#{event.id}/rfid/missed_scans", headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['tickets'].map { |row| [row['ticket_name'], row['reason']] })
        .to contain_exactly(['Ahmad Bin Ali', 'no_read'], ['No Sticker', 'no_tag'])

      get "/v1/events/#{event.id}/rfid/missed_scans", params: { reason: 'no_tag' }, headers: headers
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['No Sticker'])

      observe_via_device(device_key, [reading('entry', base)])
      get "/v1/events/#{event.id}/rfid/missed_scans", params: { reason: 'no_read' }, headers: headers
      expect(body['tickets']).to eq([])
    end

    it 'finds a guest by name, ticket id or email and filters by ticket type' do
      other_type = create(:ticket_type, event: event, name: 'VIP')
      vip = create(:ticket, :paid, :checked_in, event: event, ticket_type: other_type,
                                                 attendee_name: 'Zainab Vip', attendee_email: 'zainab@example.com',
                                                 check_in_at: base)

      get "/v1/events/#{event.id}/rfid/missed_scans", params: { q: 'zain' }, headers: headers
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['Zainab Vip'])

      get "/v1/events/#{event.id}/rfid/missed_scans", params: { q: vip.public_id[0, 8] }, headers: headers
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['Zainab Vip'])

      get "/v1/events/#{event.id}/rfid/missed_scans", params: { q: 'ZAINAB@EXAMPLE' }, headers: headers
      expect(body['tickets'].length).to eq(1)

      get "/v1/events/#{event.id}/rfid/missed_scans", params: { ticket_type_id: ticket_type.id },
                                                      headers: headers
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['Ahmad Bin Ali'])
      expect(body['ticket_types'].map { |type| type['name'] }).to include('Delegate', 'VIP')
    end

    it 'rejects an unknown reason' do
      get "/v1/events/#{event.id}/rfid/missed_scans", params: { reason: 'bogus' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'is refused to a member without analytics access' do
      get "/v1/events/#{event.id}/rfid/missed_scans", headers: auth_headers(member)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'sessions, eligibility and flow' do
    before { bind_via_device(device_key) }

    def add_session(**attrs)
      post "/v1/events/#{event.id}/rfid/sessions",
           params: { name: 'Keynote', starts_at: base.iso8601, ends_at: (base + 100.minutes).iso8601,
                     mandatory: true }.merge(attrs), headers: headers, as: :json
    end

    it 'creates, lists and deletes a session with its attendance' do
      observe_via_device(device_key, [reading('entry', base + 10.minutes),
                                      reading('exit', base + 100.minutes)])

      add_session
      expect(response).to have_http_status(:created), response.body
      expect(body['session']).to include('name' => 'Keynote', 'mandatory' => true, 'attended' => 1)

      get "/v1/events/#{event.id}/rfid/sessions", headers: headers
      expect(body['attendance_percent']).to eq(80)
      expect(body['sessions'].length).to eq(1)

      delete "/v1/events/#{event.id}/rfid/sessions/#{body['sessions'].first['id']}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(event.rfid_sessions.count).to eq(0)
    end

    it 'lists a session\'s attendees once each, adding up several in/out visits' do
      add_session(name: 'Keynote')
      id = body['session']['id']
      # Two visits (a break in between) inside the 100 minute window = one guest.
      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 40.minutes),
                                      reading('entry', base + 50.minutes),
                                      reading('exit', base + 90.minutes)])

      get "/v1/events/#{event.id}/rfid/sessions/#{id}/attendees", headers: headers

      expect(response).to have_http_status(:ok), response.body
      expect(body['attendees'].length).to eq(1)
      row = body['attendees'].first
      expect(row).to include('visit_count' => 2, 'seconds' => 4800, 'percent' => 80, 'attended' => true)
      expect(row['segments'].map { |segment| segment['seconds'] }).to eq([2400, 2400])
      expect(body['counts']).to eq('attended' => 1, 'partial' => 0)

      get "/v1/events/#{event.id}/rfid/sessions/#{id}/attendees", params: { status: 'partial' },
                                                                  headers: headers
      expect(body['attendees']).to eq([])
    end

    it 'filters eligibility and attendees by search and ticket type' do
      add_session(name: 'Keynote')
      id = body['session']['id']
      vip = create(:ticket_type, event: event, name: 'VIP')
      create(:ticket, :paid, :checked_in, event: event, ticket_type: vip, attendee_name: 'Zainab Vip',
                                          attendee_email: 'zainab@example.com', check_in_at: base)

      get "/v1/events/#{event.id}/rfid/eligibility", params: { q: 'zainab' }, headers: headers
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['Zainab Vip'])
      expect(body['ticket_types'].map { |type| type['name'] }).to include('Delegate', 'VIP')

      get "/v1/events/#{event.id}/rfid/eligibility", params: { ticket_type_id: ticket_type.id }, headers: headers
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['Ahmad Bin Ali'])

      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 90.minutes)])
      get "/v1/events/#{event.id}/rfid/sessions/#{id}/attendees", params: { ticket_type_id: vip.id },
                                                                  headers: headers
      expect(body['attendees']).to eq([])
      get "/v1/events/#{event.id}/rfid/sessions/#{id}/attendees", params: { ticket_type_id: ticket_type.id },
                                                                  headers: headers
      expect(body['attendees'].length).to eq(1)
    end

    it 'rejects a session that ends before it starts' do
      add_session(ends_at: (base - 1.hour).iso8601)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lists eligibility with the status filter and changes the threshold' do
      add_session
      patch "/v1/events/#{event.id}/rfid/settings", params: { attendance_percent: 50 },
                                                    headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(body['settings']['attendance_percent']).to eq(50)

      get "/v1/events/#{event.id}/rfid/eligibility", params: { status: 'not_qualified' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(body['tickets'].map { |row| row['ticket_name'] }).to eq(['Ahmad Bin Ali'])

      get "/v1/events/#{event.id}/rfid/eligibility", params: { status: 'bogus' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an out-of-range attendance percent' do
      patch "/v1/events/#{event.id}/rfid/settings", params: { attendance_percent: 120 },
                                                    headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns the arrivals timeline' do
      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 30.minutes)])

      get "/v1/events/#{event.id}/rfid/flow", headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['interval_minutes']).to eq(5)
      expect(body['buckets'].sum { |bucket| bucket['entries'] }).to eq(1)
      expect(body['buckets'].last['inside']).to eq(0)
    end

    it 'limits the timeline to a window and carries guests already inside into it' do
      observe_via_device(device_key, [reading('entry', base), reading('exit', base + 2.hours)])

      get "/v1/events/#{event.id}/rfid/flow",
          params: { from: (base + 1.hour).iso8601, to: (base + 3.hours).iso8601 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['interval_minutes']).to eq(5)
      expect(body['buckets'].first['inside']).to eq(1)
      expect(body['buckets'].sum { |bucket| bucket['entries'] }).to eq(0)
      expect(body['buckets'].last['inside']).to eq(0)
    end

    it 'rejects a flow window that is backwards or malformed' do
      get "/v1/events/#{event.id}/rfid/flow",
          params: { from: base.iso8601, to: (base - 1.hour).iso8601 }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      get "/v1/events/#{event.id}/rfid/flow", params: { from: 'yesterday' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'keeps sessions staff-only' do
      get "/v1/events/#{event.id}/rfid/sessions", headers: auth_headers(member)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET anomalies' do
    before { bind_via_device(device_key) }

    it 'shows the original and current meaning of a corrected reading' do
      # The gate reads a sticker the desk has not linked yet (offline binding).
      late_tag = '00000000000000FF'
      delivery = SecureRandom.uuid
      observe_via_device(device_key, [reading('exit', base - 30.minutes, uid: late_tag,
                                              delivery: delivery)])

      get "/v1/events/#{event.id}/rfid/anomalies", headers: headers
      expect(response).to have_http_status(:ok)
      expect(body['observations'].sole).to include('current_outcome' => 'unknown_tag')

      late_ticket = create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                                  attendee_name: 'Late Binding',
                                                  check_in_at: base - 2.hours)
      post '/v1/rfid/bindings',
           params: { public_id: late_ticket.public_id, protocol: 'iso15693',
                     uid_raw_hex: late_tag, mode: 'bind', payload_version: nil,
                     operation_id: SecureRandom.uuid, captured_at: (base - 1.hour).iso8601(6),
                     replace: false, reason: nil },
           headers: device_headers(device_key), as: :json
      expect(response).to have_http_status(:created), response.body

      get "/v1/events/#{event.id}/rfid/anomalies", headers: headers

      expect(response).to have_http_status(:ok)
      row = body['observations'].sole
      expect(row).to include('original_outcome' => 'unknown_tag', 'current_outcome' => 'accepted',
                             'station_key' => station_key, 'role' => 'exit')
      expect(Time.iso8601(row['captured_at'])).to eq(base - 30.minutes)
      expect(body['pagination']['total_count']).to eq(1)
    end
  end

  describe 'PATCH settings' do
    it 'changes only the rfid settings' do
      original_title = event.title

      patch "/v1/events/#{event.id}/rfid/settings",
            params: { rfid_mode: 'write', require_check_in: true, title: 'Hijacked' },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['settings']).to eq('event_id' => event.id, 'rfid_mode' => 'write',
                                     'require_check_in' => true, 'attendance_percent' => 80)
      expect(event.reload.title).to eq(original_title)
    end

    it 'rejects an unknown mode, a non-boolean flag and an empty payload' do
      [{ rfid_mode: 'sticker' }, { require_check_in: 'yes' }, {}].each do |payload|
        patch "/v1/events/#{event.id}/rfid/settings", params: payload, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_content), payload.inspect
        expect(body['success']).to be(false), payload.inspect
      end

      expect(event.reload.rfid_mode).to eq('bind')
    end

    it 'needs event staff rights for settings as well as reads' do
      patch "/v1/events/#{event.id}/rfid/settings", params: { rfid_mode: 'write' },
                                                    headers: auth_headers(member), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(event.reload.rfid_mode).to eq('bind')

      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
            params: { role: 'exit', reason: 'x', confirm: true },
            headers: auth_headers(member), as: :json
      expect(response).to have_http_status(:forbidden)
      expect(gate.reload.role).to be_nil
    end
  end

  describe 'PATCH stations' do
    it 'needs a reason and an explicit confirmation, then records the change' do
      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}", params: { role: 'exit' },
                                                               headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
            params: { role: 'exit', reason: '  ' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
            params: { role: 'exit', reason: 'door sign says exit', confirm: true },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['station']).to include('role' => 'exit', 'uid_rule' => 'as_is')
      expect(gate.reload.role).to eq('exit')

      correction = Rfid::Correction.sole
      expect(correction).to have_attributes(kind: 'station_change', reason: 'door sign says exit',
                                            actor: owner, station_id: gate.id)
      expect(correction.details).to include('role' => 'exit')
    end

    it 'never rewrites a raw reading, and only re-measures named observations' do
      late_tag = '00000000000000FF'
      delivery = SecureRandom.uuid
      observe_via_device(device_key, [reading('exit', base, uid: late_tag, delivery: delivery)])
      observation = Rfid::Observation.find_by(delivery_id: delivery)

      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
            params: { role: 'exit', uid_rule: 'reversed', reason: 'verified on the door',
                      confirm: true, observation_ids: [observation.id] },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Rfid::Correction.sole.details).to include('observation_ids' => [observation.id.to_s])

      observation.reload
      expect(observation.role).to eq('exit')
      expect(observation.tag_key).to eq(late_tag)
      expect(observation.original_response['outcome']).to eq('unknown_tag')
      expect(observation.device_metadata).to eq(
        'device_direction_raw' => nil, 'device_time_raw_hex' => nil, 'flags_raw' => {}
      )
    end

    it 'applies selected historical role correction to visit projection' do
      bind_via_device(device_key)
      delivery = SecureRandom.uuid
      observe_via_device(device_key, [reading('entry', base, delivery: delivery)])
      observation = Rfid::Observation.find_by!(delivery_id: delivery)
      expect(event.rfid_visits.open.count).to eq(1)

      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
            params: { role: 'exit', reason: 'gate was marked backward', confirm: true,
                      observation_ids: [observation.id] }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(observation.reload.role).to eq('entry')
      expect(observation.original_response['outcome']).to eq('accepted')
      expect(event.rfid_visits.open.count).to eq(0)
    end

    it 'rejects observation IDs outside this station and event' do
      foreign = create(:event, use_api_access: true)
      foreign_station = Rfid::Station.create!(event: foreign, station_key: 'foreign-gate',
                                             kind: 'gate', role: 'entry')
      foreign_read = Rfid::Observation.create!(
        event: foreign, station: foreign_station, delivery_id: SecureRandom.uuid,
        role: 'entry', protocol: 'iso15693', uid_raw_hex: 'AABB', tag_key: 'AABB',
        captured_at: base, outcome: 'unknown_tag', request_digest: 'a' * 64,
        original_response: { delivery_id: SecureRandom.uuid, outcome: 'unknown_tag',
                             anomalies: [], display: {} }
      )

      patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
            params: { role: 'exit', reason: 'wrong gate', confirm: true,
                      observation_ids: [foreign_read.id] }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(gate.reload.role).to be_nil
      expect(Rfid::Correction.count).to eq(0)
    end

    it 'rejects an unknown station and a bad role or uid rule' do
      patch "/v1/events/#{event.id}/rfid/stations/0",
            params: { role: 'exit', reason: 'x', confirm: true }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)

      [{ role: 'sideways' }, { uid_rule: 'flipped' }].each do |payload|
        patch "/v1/events/#{event.id}/rfid/stations/#{gate.id}",
              params: payload.merge(reason: 'x', confirm: true), headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_content), payload.inspect
      end
    end
  end

  describe 'POST manual exit' do
    before { bind_via_device(device_key) }

    def open_visit
      observe_via_device(device_key, [reading('entry', base)])
      event.rfid_visits.open.sole
    end

    it 'closes the named visit, records the actor and reason, and survives a rebuild' do
      visit = open_visit

      post "/v1/events/#{event.id}/rfid/visits/#{visit.id}/manual_exit",
           params: { at: (base + 20.minutes).iso8601(6), reason: 'guest left early' },
           headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['visit']).to include('manual' => true, 'duration_seconds' => 20 * 60,
                                       'anomalies' => ['manual_exit'])
      visit.reload
      expect(visit.exit_at).to eq(base + 20.minutes)
      expect(visit.manual).to be(true)
      expect(visit.exit_observation_id).to be_nil

      correction = Rfid::Correction.sole
      expect(correction).to have_attributes(kind: 'manual_exit', actor: owner,
                                            entry_observation_id: visit.entry_observation_id,
                                            exit_at: base + 20.minutes)

      Rfid::Visits.rebuild!(event: event)
      expect(visit.reload.manual).to be(true)
      expect(visit.exit_at).to eq(base + 20.minutes)
      expect(Rfid::Correction.count).to eq(1)
    end

    it 'requires a reason, a time that is not before the entry, and an open visit' do
      visit = open_visit
      path = "/v1/events/#{event.id}/rfid/visits/#{visit.id}/manual_exit"

      post path, params: { at: (base + 5.minutes).iso8601(6), reason: ' ' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: { at: (base - 5.minutes).iso8601(6), reason: 'before' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: { at: 'yesterday', reason: 'bad time' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      expect(Rfid::Correction.count).to eq(0)
      expect(visit.reload.open?).to be(true)

      post path, params: { at: (base + 5.minutes).iso8601(6), reason: 'left' }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)

      post path, params: { at: (base + 25.minutes).iso8601(6), reason: 'again' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(Rfid::Correction.count).to eq(1)
    end

    it 'rejects an unknown visit' do
      post "/v1/events/#{event.id}/rfid/visits/0/manual_exit",
           params: { at: base.iso8601(6), reason: 'x' }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST visits/manual_exit_all' do
    let(:path) { "/v1/events/#{event.id}/rfid/visits/manual_exit_all" }

    before { bind_via_device(device_key) }

    it 'closes every open visit with one correction each and survives a rebuild' do
      observe_via_device(device_key, [reading('entry', base)])
      visit = event.rfid_visits.open.sole

      post path, params: { at: (base + 30.minutes).iso8601(6), reason: 'hall empty' },
                 headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body).to eq('closed' => 1)
      expect(visit.reload).to have_attributes(exit_at: base + 30.minutes, manual: true)
      expect(Rfid::Correction.sole).to have_attributes(kind: 'manual_exit', actor: owner)

      Rfid::Visits.rebuild!(event: event)
      expect(event.rfid_visits.open.count).to eq(0)

      post path, params: { at: (base + 31.minutes).iso8601(6), reason: 'again' }, headers: headers, as: :json
      expect(body).to eq('closed' => 0)
    end

    it 'reports the sweep in the summary and undoes it' do
      observe_via_device(device_key, [reading('entry', base)])

      post path, params: { at: (base + 30.minutes).iso8601(6), reason: 'hall empty' }, headers: headers, as: :json
      get "/v1/events/#{event.id}/rfid/summary", headers: headers
      expect(body['last_bulk_exit']).to include('closed' => 1)

      delete path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(body).to eq('reopened' => 1)
      expect(event.rfid_visits.open.count).to eq(1)
      expect(Rfid::Correction.count).to eq(0)

      delete path, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'counts stale open visits and unmatched exits in the summary' do
      observe_via_device(device_key, [reading('entry', base)])
      get "/v1/events/#{event.id}/rfid/summary", headers: headers
      expect(body).to include('likely_gone' => 1, 'stale_hours' => 6, 'unmatched_exits' => 0)
    end

    it 'needs a reason and a time that is not in the future' do
      post path, params: { at: base.iso8601(6), reason: ' ' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: { at: 1.hour.from_now.iso8601, reason: 'x' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST visits/manual_entry' do
    let(:guest) { create(:ticket, :paid, event: event) }
    let(:path) { "/v1/events/#{event.id}/rfid/visits/manual_entry" }
    let(:params) do
      { ticket_public_id: guest.public_id, entry_at: (base + 10.minutes).iso8601(6),
        exit_at: (base + 40.minutes).iso8601(6), reason: 'IN gate was down' }
    end

    it 'adds an audited visit that counts for attendance and survives a rebuild' do
      session = Rfid::Session.create!(event: event, name: 'Keynote', starts_at: base,
                                      ends_at: base + 60.minutes, mandatory: true)

      post path, params: params, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['visit']).to include('ticket_public_id' => guest.public_id, 'duration_seconds' => 30 * 60,
                                       'anomalies' => ['manual_entry'], 'entry_station' => nil)
      expect(Rfid::Correction.sole).to have_attributes(kind: 'manual_entry', actor: owner, ticket: guest)

      Rfid::Visits.rebuild!(event: event)
      expect(event.rfid_visits.count).to eq(1)
      row = Rfid::Attendance.new(event, now: base + 2.hours).sessions.find { |item| item[:id] == session.id }
      expect(row[:present]).to eq(1)
    end

    it 'leaves the visit open without an exit, and the next real exit closes it' do
      bind_via_device(device_key)
      post path, params: params.except(:exit_at).merge(ticket_public_id: ticket.public_id),
           headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['visit']).to include('status' => 'open', 'anomalies' => ['manual_entry'])

      results = observe_via_device(device_key, [reading('exit', base + 50.minutes)])
      visit = event.rfid_visits.sole
      expect(visit).to have_attributes(exit_at: base + 50.minutes, correction_id: Rfid::Correction.sole.id)
      expect(visit.exit_observation_id).to be_present
      expect(Rfid::Observation.sole.anomalies).not_to include('unmatched_exit')
      expect(results.first['outcome']).to eq('accepted')
    end

    it 'rejects a missing reason, a reversed range, a future exit, an overlap and an unknown ticket' do
      post path, params: params.merge(reason: ' '), headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: params.merge(exit_at: (base).iso8601(6)), headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: params.merge(exit_at: 1.day.from_now.iso8601(6)), headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: params.merge(ticket_public_id: SecureRandom.uuid), headers: headers, as: :json
      expect(response).to have_http_status(:not_found)

      post path, params: params, headers: headers, as: :json
      post path, params: params.merge(entry_at: (base + 20.minutes).iso8601(6)), headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(Rfid::Correction.count).to eq(1)
    end
  end

  describe 'attendance_check' do
    it 'previews the groups and refuses to notify without a webhook url or valid reasons' do
      create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type, attendee_phone: '0111111111')
      get "/v1/events/#{event.id}/rfid/attendance_check", headers: headers
      expect(response).to have_http_status(:ok)
      expect(body).to include('webhook_configured' => false)

      post "/v1/events/#{event.id}/rfid/attendance_check/notify",
           params: { reasons: ['never_detected'] }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      event.update!(webhook_url: 'https://hooks.example.com/a')
      post "/v1/events/#{event.id}/rfid/attendance_check/notify",
           params: { reasons: ['bogus'] }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post "/v1/events/#{event.id}/rfid/attendance_check/notify",
           params: { reasons: ['never_detected'] }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(body).to include('sent' => 1)
    end
  end

  describe 'POST/DELETE eligibility/:ticket_id/override' do
    let(:guest) { create(:ticket, :paid, event: event) }
    let(:path) { "/v1/events/#{event.id}/rfid/eligibility/#{guest.id}/override" }

    before do
      Rfid::Session.create!(event: event, name: 'Keynote', starts_at: base,
                            ends_at: base + 100.minutes, mandatory: true)
    end

    it 'records an audited grant and reports it on the guest row' do
      post path, params: { reason: 'left to handle logistics' }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['ticket']['override']).to include('reason' => 'left to handle logistics')
      expect(Rfid::Correction.sole).to have_attributes(kind: 'cert_override', actor: owner, ticket: guest)
    end

    it 'requires a reason and an active paid ticket of this event' do
      post path, params: { reason: ' ' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post "/v1/events/#{event.id}/rfid/eligibility/0/override",
           params: { reason: 'x' }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(Rfid::Correction.count).to eq(0)
    end

    it 'revokes without deleting the grant' do
      post path, params: { reason: 'logistics' }, headers: headers, as: :json
      delete path, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['ticket']['override']).to be_nil
      expect(Rfid::Correction.pluck(:kind)).to eq(%w[cert_override cert_override_revoked])
    end
  end

  describe 'POST eligibility/bulk_override' do
    let(:path) { "/v1/events/#{event.id}/rfid/eligibility/bulk_override" }
    let!(:near)  { create(:ticket, :paid, event: event) }
    let!(:far)   { create(:ticket, :paid, event: event) }
    let!(:full)  { create(:ticket, :paid, event: event) }

    before do
      event.update!(rfid_attendance_percent: 80)
      Rfid::Session.create!(event: event, name: 'Keynote', starts_at: base,
                            ends_at: base + 100.minutes, mandatory: true)
      visit = lambda do |ticket, minutes|
        observation = create(:rfid_observation, event: event, station: gate, outcome: 'accepted')
        Rfid::Visit.create!(event: event, ticket: ticket, ticket_public_id: ticket.public_id, ticket_name: 'Guest',
                            entry_observation: observation, entry_at: base, exit_at: base + minutes.minutes)
      end
      visit.call(near, 70)  # 70% - short of 80%
      visit.call(far, 10)   # 10%
      visit.call(full, 90)  # 90% - already met
    end

    it 'reports how many guests would be waived without changing anything' do
      post path, params: { dry_run: true }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body).to include('count' => 2, 'dry_run' => true)
      expect(body['guests'].map { |guest| guest['lowest_percent'] }).to contain_exactly(10.0, 70.0)
      expect(Rfid::Correction.count).to eq(0)
    end

    it 'waives only the guests matching the filters, skipping those who already met it' do
      post path, params: { reason: 'gate lag, organizer approved', min_percent: 50 }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body).to include('count' => 1)
      expect(Rfid::Correction.where(kind: 'cert_override').pluck(:ticket_id)).to eq([near.id])
      expect(Rfid::Correction.sole).to have_attributes(actor: owner, reason: 'gate lag, organizer approved')
    end

    it 'narrows the waive by a custom registration field and lists the available fields' do
      near.update!(custom_fields_data: { 'category' => 'Agensi' })
      far.update!(custom_fields_data: { 'category' => 'Swasta' })

      get "/v1/events/#{event.id}/rfid/eligibility/fields", headers: headers
      expect(body['fields']).to include('key' => 'category', 'values' => %w[Agensi Swasta])

      post path, params: { dry_run: true, custom_fields: { category: 'Agensi' } }, headers: headers, as: :json
      expect(body).to include('count' => 1)
      post path, params: { reason: 'agency exception', custom_fields: { category: 'Agensi' } }, headers: headers, as: :json
      expect(Rfid::Correction.where(kind: 'cert_override').pluck(:ticket_id)).to eq([near.id])
    end

    it 'filters by event day: came any day, every day, or only some days' do
      day1 = Rfid::Session.find_by!(event: event, name: 'Keynote')
      day2 = Rfid::Session.create!(event: event, name: 'Day 2', starts_at: base + 1.day,
                                   ends_at: base + 1.day + 100.minutes, mandatory: true)
      create(:ticket, :paid, event: event) # never came: held in every mode
      observation = create(:rfid_observation, event: event, station: gate, outcome: 'accepted')
      Rfid::Visit.create!(event: event, ticket: near, ticket_public_id: near.public_id, ticket_name: 'Guest',
                          entry_observation: observation, entry_at: base + 1.day,
                          exit_at: base + 1.day + 30.minutes) # near came on both days
      days = [[day1.id], [day2.id]]
      count = lambda do |mode|
        post path, params: { dry_run: true, attended_days: days, attended_mode: mode }, headers: headers, as: :json
        body['count']
      end

      expect(count.call('any')).to eq(3)     # near, far, full; the 0% guest held
      expect(count.call('all')).to eq(1)     # near only
      expect(count.call('partial')).to eq(2) # far + full came day 1 only

      post path, params: { dry_run: true, attended_mode: 'bogus' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'matches any of several values for one registration field' do
      near.update!(custom_fields_data: { 'category' => 'Agensi' })
      far.update!(custom_fields_data: { 'category' => 'Swasta' })
      full.update!(custom_fields_data: { 'category' => 'Lain' })

      post path, params: { dry_run: true, custom_fields: { category: %w[Agensi Swasta] } }, headers: headers, as: :json
      expect(body['guests'].map { |guest| guest['ticket_public_id'] }).to contain_exactly(near.public_id, far.public_id)
    end

    it 'does not waive anyone twice' do
      2.times { post path, params: { reason: 'gate lag' }, headers: headers, as: :json }

      expect(Rfid::Correction.where(kind: 'cert_override').count).to eq(2)
      expect(body).to include('count' => 0)
    end

    it 'requires a reason and a numeric min_percent' do
      post path, params: {}, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: { reason: 'x', min_percent: 'abc' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(Rfid::Correction.count).to eq(0)
    end
  end

  describe 'GET report.xlsx' do
    def sheet_rows(name)
      file = Tempfile.new(['rfid-report', '.xlsx'], binmode: true)
      file.write(response.body)
      file.flush
      Roo::Excelx.new(file.path).sheet(name).parse
    end

    it 'exports this event only, as plain-language sheets with no contact, key or live formula' do
      formula_title_type = create(:ticket_type, event: event, name: '=IMPORTXML("x")')
      formula_ticket = create(:ticket, :paid, :checked_in, event: event,
                                                ticket_type: formula_title_type,
                                                attendee_name: '=cmd|calc',
                                                attendee_email: 'formula@example.com',
                                                attendee_phone: '0199999999',
                                                check_in_at: base - 1.minute)
      Rfid::Binding.create!(event: event, ticket: formula_ticket,
                            ticket_public_id: formula_ticket.public_id,
                            ticket_name: formula_ticket.attendee_name, protocol: 'iso15693',
                            uid_raw_hex: tag, tag_key: tag, mode: 'bind',
                            captured_at: base - 1.hour, operation_id: SecureRandom.uuid)
      bind_via_device(device_key, uid: 'AABBCCDD00112233')

      observe_via_device(device_key, [reading('entry', base, uid: tag, delivery: SecureRandom.uuid)])
      observe_via_device(device_key, [reading('entry', base + 1.minute, uid: 'AABBCCDD00112233',
                                              delivery: SecureRandom.uuid)])
      visit = event.rfid_visits.find_by(ticket_id: formula_ticket.id)
      Rfid::Correction.create!(event: event, actor: owner,
                               entry_observation: visit.entry_observation, kind: 'manual_exit',
                               exit_at: base + 5.minutes, reason: 'left')
      Rfid::Visits.rebuild!(event: event)

      get "/v1/events/#{event.id}/rfid/report.xlsx", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('spreadsheetml.sheet')
      expect(response.headers['Content-Disposition']).to include('.xlsx')

      log = sheet_rows('Guest Visits').flatten.compact.map(&:to_s)
      expect(log).to include('=cmd|calc', formula_ticket.public_id.to_s)
      expect(log).not_to include('formula@example.com', '0199999999')
      expect(sheet_rows('Summary').flatten.compact.map(&:to_s)).to include('Venue at a glance')
      expect(response.body).not_to include(device_key.raw_key)
    end
  end
end
