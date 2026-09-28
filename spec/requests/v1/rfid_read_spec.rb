require 'rails_helper'

# Plan 5 Task 3: the read half of the device API. Every answer is unwrapped
# JSON matching `rfidex-core`'s DTOs, the event comes from the key, and no full
# contact value ever leaves the server.
RSpec.describe 'V1::Rfid reads', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true) }
  let(:key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let(:station) { 'desk-contract' }
  let(:headers) { { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station } }

  def body
    JSON.parse(response.body)
  end

  # ---------------------------------------------------------------- heartbeat
  describe 'POST /v1/rfid/stations/heartbeat' do
    let(:heartbeat) do
      { name: 'Registration desk', kind: 'desk', role: nil, hw_model: 'ECRFID-1',
        firmware: '1.2.3', app_version: '0.3.0' }
    end

    it 'registers the station and answers the event settings' do
      expect do
        post '/v1/rfid/stations/heartbeat', params: heartbeat, headers: headers, as: :json
      end.to change(Rfid::Station, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(body).to eq(
        'event' => { 'event_id' => event.id, 'name' => event.title, 'rfid_mode' => 'bind',
                     'require_check_in' => false },
        'uid_rule' => 'as_is',
        'server_time' => body['server_time']
      )
      expect(Time.iso8601(body['server_time'])).to be_within(5.seconds).of(Time.current)

      saved = Rfid::Station.find_by(event: event, station_key: station)
      expect(saved).to have_attributes(name: 'Registration desk', kind: 'desk', role: nil,
                                       hw_model: 'ECRFID-1', firmware: '1.2.3',
                                       app_version: '0.3.0', uid_rule: 'as_is')
      expect(saved.last_heartbeat_at).to be_within(5.seconds).of(Time.current)
    end

    it 'records the first role and reports the configured event settings' do
      event.update!(rfid_mode: 'write', rfid_require_check_in: true)

      post '/v1/rfid/stations/heartbeat',
           params: heartbeat.merge(kind: 'gate', role: 'entry'), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(body['event']).to include('rfid_mode' => 'write', 'require_check_in' => true)
      expect(Rfid::Station.find_by(station_key: station).role).to eq('entry')
    end

    it 'updates status fields on the next heartbeat without a second station' do
      post '/v1/rfid/stations/heartbeat', params: heartbeat, headers: headers, as: :json

      expect do
        post '/v1/rfid/stations/heartbeat',
             params: heartbeat.merge(name: 'Desk 1', app_version: '0.4.0'), headers: headers,
             as: :json
      end.not_to change(Rfid::Station, :count)

      expect(response).to have_http_status(:ok)
      expect(Rfid::Station.find_by(station_key: station))
        .to have_attributes(name: 'Desk 1', app_version: '0.4.0')
    end

    it 'refuses a changed role with a typed 409 and leaves the stored role alone' do
      post '/v1/rfid/stations/heartbeat',
           params: heartbeat.merge(kind: 'gate', role: 'entry'), headers: headers, as: :json

      post '/v1/rfid/stations/heartbeat',
           params: heartbeat.merge(kind: 'gate', role: 'exit'), headers: headers, as: :json

      expect(response).to have_http_status(:conflict)
      expect(body).to eq('error' => 'malformed', 'message' => body['message'],
                         'holder' => nil, 'binding' => nil)
      expect(Rfid::Station.find_by(station_key: station).role).to eq('entry')
    end

    it 'accepts the same role again' do
      post '/v1/rfid/stations/heartbeat',
           params: heartbeat.merge(kind: 'gate', role: 'entry'), headers: headers, as: :json
      post '/v1/rfid/stations/heartbeat',
           params: heartbeat.merge(kind: 'gate', role: 'entry'), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'ignores unknown fields, the way the Rust client tolerates a newer server' do
      post '/v1/rfid/stations/heartbeat',
           params: heartbeat.merge(future_field: 'ignored'), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a malformed body with a typed 400' do
      [
        heartbeat.except(:name),
        heartbeat.merge(kind: 'kiosk'),
        heartbeat.merge(role: 'sideways'),
        heartbeat.merge(app_version: ''),
        heartbeat.merge(name: 'x' * 256)
      ].each do |payload|
        post '/v1/rfid/stations/heartbeat', params: payload, headers: headers, as: :json

        expect(response).to have_http_status(:bad_request), payload.inspect
        expect(body['error']).to eq('malformed'), payload.inspect
        expect(body.keys).to contain_exactly('error', 'message', 'holder', 'binding')
      end
    end

    it 'rejects a non-JSON body with a typed 400' do
      post '/v1/rfid/stations/heartbeat', params: 'not json', headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')
    end
  end

  # ------------------------------------------------------------ station header
  describe 'the station header' do
    it 'rejects a missing header with a typed 400' do
      get '/v1/rfid/cache', headers: { 'Authorization' => key.raw_key }

      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')
      expect(body.keys).to contain_exactly('error', 'message', 'holder', 'binding')
    end

    it 'rejects a blank, non-printable or oversized header' do
      ['', '   ', "desk\u0000", 'x' * 129].each do |value|
        get '/v1/rfid/cache',
            headers: { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => value }

        expect(response).to have_http_status(:bad_request), value.inspect
        expect(body['error']).to eq('malformed'), value.inspect
      end
    end

    it 'takes the header as an opaque key, spaces and all' do
      post '/v1/rfid/stations/heartbeat',
           params: { name: 'Desk', kind: 'desk', app_version: '0.3.0' },
           headers: { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => 'desk 2 back office' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(Rfid::Station.find_by(station_key: 'desk 2 back office')).to be_present
    end
  end

  # --------------------------------------------------------------------- auth
  describe 'key scoping' do
    it 'rejects a missing key, a wrong key and a revoked key with 401' do
      get '/v1/rfid/cache', headers: { 'X-RfiDex-Station' => station }
      expect(response).to have_http_status(:unauthorized)

      get '/v1/rfid/cache',
          headers: { 'Authorization' => 'wrong_key_wrong_key_wrong_key_xx',
                     'X-RfiDex-Station' => station }
      expect(response).to have_http_status(:unauthorized)

      key.revoke!
      get '/v1/rfid/cache', headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects an ordinary event key and an account-wide key with 401' do
      ordinary = create(:api_key, user: owner, event: event, scope: 'read_write')
      get '/v1/rfid/cache',
          headers: { 'Authorization' => ordinary.raw_key, 'X-RfiDex-Station' => station }
      expect(response).to have_http_status(:unauthorized)
      expect(body['error']).to eq('unauthorized')

      account_wide = create(:api_key, user: owner, event: nil, scope: 'rfid')
      get '/v1/rfid/cache',
          headers: { 'Authorization' => account_wide.raw_key, 'X-RfiDex-Station' => station }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # -------------------------------------------------------------------- cache
  describe 'GET /v1/rfid/cache' do
    let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
    let!(:paid) { create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Aina Demo') }
    let!(:unpaid) { create(:ticket, event: event, ticket_type: ticket_type, attendee_name: 'Ben Unpaid') }
    let!(:checked_in) do
      create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                         attendee_name: 'Chong Entered',
                                         attendee_email: 'chong@example.com',
                                         attendee_phone: '0123456789')
    end

    before do
      Rfid::Binding.create!(event: event, ticket: paid, ticket_public_id: paid.public_id,
                            ticket_name: paid.attendee_name, protocol: 'iso15693',
                            uid_raw_hex: '3412CDAB500104E0', tag_key: '3412CDAB500104E0',
                            mode: 'bind', captured_at: 1.hour.ago, operation_id: SecureRandom.uuid)
      Rfid::Binding.create!(event: event, ticket: unpaid, ticket_public_id: unpaid.public_id,
                            ticket_name: unpaid.attendee_name, protocol: 'iso15693',
                            uid_raw_hex: 'AABBCCDD', tag_key: 'AABBCCDD', mode: 'written',
                            captured_at: 2.hours.ago, revoked_at: 1.minute.ago,
                            revocation_reason: 'sticker swapped',
                            operation_id: SecureRandom.uuid)
    end

    it 'returns the full snapshot the station needs to work offline' do
      get '/v1/rfid/cache', headers: headers

      expect(response).to have_http_status(:ok)
      expect(body.keys).to contain_exactly('tickets', 'bindings', 'revoked_tag_keys', 'server_time')
      expect(Time.iso8601(body['server_time'])).to be_within(5.seconds).of(Time.current)

      rows = body['tickets'].index_by { |t| t['public_id'] }
      expect(rows.keys).to contain_exactly(paid.public_id, unpaid.public_id, checked_in.public_id)
      expect(rows[paid.public_id]).to eq(
        'public_id' => paid.public_id, 'name' => 'Aina Demo', 'ticket_type' => 'Delegate',
        'valid' => true, 'checked_in' => false
      )
      expect(rows[unpaid.public_id]['valid']).to be(false)
      expect(rows[checked_in.public_id]['checked_in']).to be(true)

      expect(body['bindings'].length).to eq(1)
      expect(body['bindings'][0]).to eq(
        'id' => Rfid::Binding.active.first.id, 'public_id' => paid.public_id,
        'protocol' => 'iso15693', 'uid_raw_hex' => '3412CDAB500104E0',
        'tag_key' => '3412CDAB500104E0', 'mode' => 'bind'
      )
      expect(body['revoked_tag_keys']).to eq(['AABBCCDD'])
    end

    it 'never carries a contact or a hint' do
      get '/v1/rfid/cache', headers: headers

      expect(response.body).not_to include('chong@example.com', '0123456789')
      %w[email phone hint].each do |field|
        expect(response.body).not_to include(field)
      end
    end

    it 'answers the same full snapshot whatever `since` says' do
      get '/v1/rfid/cache', headers: headers
      full = body

      get '/v1/rfid/cache', params: { since: 1.year.from_now.iso8601 }, headers: headers

      expect(body['tickets']).to match_array(full['tickets'])
      expect(body['bindings']).to match_array(full['bindings'])
      expect(body['revoked_tag_keys']).to eq(full['revoked_tag_keys'])
    end

    it 'lists a revoked key again once its sticker is rebound' do
      Rfid::Binding.create!(event: event, ticket: unpaid, ticket_public_id: unpaid.public_id,
                            ticket_name: unpaid.attendee_name, protocol: 'iso15693',
                            uid_raw_hex: 'AABBCCDD', tag_key: 'AABBCCDD', mode: 'bind',
                            captured_at: Time.current, operation_id: SecureRandom.uuid)

      get '/v1/rfid/cache', headers: headers

      expect(body['revoked_tag_keys']).to eq([])
      expect(body['bindings'].length).to eq(2)
    end

    it 'never shows another event' do
      other_event = create(:event, use_api_access: true)
      other_key = create(:api_key, user: owner, event: other_event, scope: 'rfid')
      other_ticket = create(:ticket, :paid, event: other_event, attendee_name: 'Zara Isolated')

      get '/v1/rfid/cache', headers: headers

      expect(body['tickets'].map { |t| t['public_id'] }).not_to include(other_ticket.public_id)
      expect(body['tickets'].map { |t| t['name'] }).not_to include('Zara Isolated')

      get '/v1/rfid/cache',
          headers: { 'Authorization' => other_key.raw_key, 'X-RfiDex-Station' => station }
      expect(body['tickets'].map { |t| t['public_id'] }).to eq([other_ticket.public_id])
    end
  end

  # ------------------------------------------------------------------- search
  describe 'GET /v1/rfid/tickets/search' do
    let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
    let(:base) { Time.zone.parse('2026-09-20T06:00:00Z') }

    def seed_ticket(n, name, created_at:, email: nil, phone: nil, payment: :paid,
                    status: :purchased, checked_in_at: nil)
      create(:ticket, event: event, ticket_type: ticket_type, attendee_name: name,
                      attendee_email: email, attendee_phone: phone, payment_status: payment,
                      status: status, public_id: format('00000000-0000-0000-0000-%012d', n),
                      created_at: created_at)
        .tap do |ticket|
        if checked_in_at
          ticket.update_columns(checked_in: true, check_in_at: checked_in_at, status: Ticket.statuses[:scanned])
        end
      end
    end

    before do
      seed_ticket(1, 'Ahmad Bin Ali', created_at: base + 1.minute,
                  email: 'Ahmad@Example.com', phone: '012-345 6789')
      seed_ticket(2, 'Ahmad Bin Ali', created_at: base + 2.minute,
                  email: 'second.ahmad@example.com', phone: '+60 12 345 6790')
      (3..12).each do |n|
        created = n == 7 ? base + 6.minutes : base + n.minutes
        seed_ticket(n, "Ahmad #{('A'..'J').to_a[n - 3]}", created_at: created)
      end
      seed_ticket(15, 'Ahmad Unpaid', created_at: base + 15.minutes, payment: :pending)
      seed_ticket(16, 'Siti %_ Nurhaliza', created_at: base + 16.minutes)
      seed_ticket(17, 'Zulkifli Cancelled', created_at: base + 17.minutes, status: :canceled)
      seed_ticket(18, 'Nur Prechecked', created_at: base + 18.minutes,
                  checked_in_at: Time.zone.parse('2026-09-25T10:00:00Z'))
      seed_ticket(19, 'Tan No Contact', created_at: base + 19.minutes)
    end

    def search(by, query)
      get '/v1/rfid/tickets/search', params: { by: by, q: query }, headers: headers
      expect(response).to have_http_status(:ok), response.body
      body['tickets']
    end

    def ids(rows)
      rows.map { |row| row['public_id'] }
    end

    it 'collapses case and spacing in a name and orders newest first' do
      packed = search('name', '  AHMAD   bin ')
      plain = search('name', 'ahmad bin')

      expect(ids(packed)).to eq(ids(plain))
      expect(ids(plain)).to eq([
        '00000000-0000-0000-0000-000000000002',
        '00000000-0000-0000-0000-000000000001'
      ])
    end

    it 'returns the ten newest matches with a stable public-id tie order' do
      rows = search('name', 'ahmad')

      expect(rows.length).to eq(10)
      expect(ids(rows)).to eq(
        [12, 11, 10, 9, 8, 6, 7, 5, 4, 3].map { |n| format('00000000-0000-0000-0000-%012d', n) }
      )
    end

    it 'treats % and _ as literal characters' do
      rows = search('name', '%_')

      expect(ids(rows)).to eq(['00000000-0000-0000-0000-000000000016'])
      expect(rows[0]['name']).to include('%_')
    end

    it 'returns nothing for a missing or too-short query' do
      expect(search('name', 'a')).to eq([])
      expect(search('name', '')).to eq([])
      expect(search('name', '   ')).to eq([])
      expect(search('name', 'nobody here at all')).to eq([])
      expect(search('phone', '012')).to eq([])
      expect(search('phone', '600')).to eq([])
      expect(search('phone', 'abc')).to eq([])
      expect(search('email', 'ahmad')).to eq([])
      expect(search('email', 'example.com')).to eq([])
    end

    it 'matches an email exactly, trims it and masks the hint' do
      rows = search('email', ' AHMAD@EXAMPLE.COM ')

      expect(ids(rows)).to eq(['00000000-0000-0000-0000-000000000001'])
      expect(rows[0]['email_hint']).to eq('ah***@example.com')
      expect(response.body).not_to include('ahmad@example.com')
      expect(rows[0].keys).to contain_exactly(
        'public_id', 'name', 'ticket_type', 'valid', 'checked_in', 'checked_in_at',
        'email_hint', 'phone_hint'
      )
      expect(rows[0]['phone_hint']).to eq('•••• 6789')
    end

    it 'accepts every phone spelling and masks the hint' do
      ['012-345 6789', '0123456789', '+60 12 345 6789'].each do |query|
        rows = search('phone', query)
        expect(ids(rows)).to eq(['00000000-0000-0000-0000-000000000001']), query
        expect(rows[0]['phone_hint']).to eq('•••• 6789'), query
      end
      expect(response.body).not_to include('0123456789')
      expect(response.body).not_to include('012-345 6789')
    end

    it 'never lists an unpaid guest' do
      expect(search('name', 'Ahmad Unpaid')).to eq([])
    end

    it 'lists a paid cancelled guest as invalid' do
      rows = search('name', 'Zulkifli')

      expect(ids(rows)).to eq(['00000000-0000-0000-0000-000000000017'])
      expect(rows[0]['valid']).to be(false)
    end

    it 'reports no hint when the guest has no contact' do
      rows = search('name', 'Tan No Contact')

      expect(ids(rows)).to eq(['00000000-0000-0000-0000-000000000019'])
      expect(rows[0]['email_hint']).to be_nil
      expect(rows[0]['phone_hint']).to be_nil
    end

    it 'carries the first check-in time of an already checked-in guest' do
      rows = search('name', 'Nur Prechecked')

      expect(rows[0]['checked_in']).to be(true)
      expect(Time.iso8601(rows[0]['checked_in_at']))
        .to eq(Time.zone.parse('2026-09-25T10:00:00Z'))
    end

    it 'rejects an unknown field, a missing q and a missing key with typed errors' do
      get '/v1/rfid/tickets/search', params: { by: 'staff', q: 'ahmad' }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')

      get '/v1/rfid/tickets/search', params: { by: 'name' }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')

      get '/v1/rfid/tickets/search', params: { by: 'name', q: 'ahmad' },
                                     headers: { 'X-RfiDex-Station' => station }
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('Ahmad')
    end

    it 'never shows another event' do
      other_event = create(:event, use_api_access: true)
      create(:ticket, :paid, event: other_event, attendee_name: 'Zara Isolated')

      expect(search('name', 'Zara Isolated')).to eq([])
    end
  end
end
