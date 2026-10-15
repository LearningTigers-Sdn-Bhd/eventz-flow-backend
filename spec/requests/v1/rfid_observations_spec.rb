require 'rails_helper'

# Plan 5 Task 6: gate readings. Raw evidence is stored once, the saved reply is
# replayed unchanged, and the current meaning is re-derived when a late binding
# or a late check-in tells the server what really happened.
RSpec.describe 'V1::Rfid observations', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true) }
  let(:key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:ticket) do
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Ahmad Bin Ali')
  end
  let(:station_key) { 'gate-entry' }
  let(:headers) { { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station_key } }
  let(:tag) { '3412CDAB500104E0' }
  let(:other_tag) { 'AABBCCDD00112233' }
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }

  def body
    JSON.parse(response.body)
  end

  def gate(role: nil, key: station_key)
    Rfid::Station.create!(event: event, station_key: key, kind: 'gate', role: role)
  end

  def bind(tag_key, target = ticket, at: base, mode: 'bind')
    Rfid::Binding.create!(event: event, ticket: target, ticket_public_id: target.public_id,
                          ticket_name: target.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: tag_key, tag_key: tag_key, mode: mode,
                          captured_at: at, operation_id: SecureRandom.uuid)
  end

  # A binding that arrives the way RfiDex sends it, so the service's own
  # reconciliation runs (a direct row insert proves nothing about it).
  def bind_via_api(tag_key, target: ticket, at: base, replace: false, reason: nil)
    post '/v1/rfid/bindings',
         params: { public_id: target.public_id, protocol: 'iso15693', uid_raw_hex: tag_key,
                   mode: 'bind', payload_version: nil, operation_id: SecureRandom.uuid,
                   captured_at: at.iso8601(6), replace: replace, reason: reason },
         headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
  end

  def item(uid: tag, role: 'entry', at: base, delivery: SecureRandom.uuid, seq: nil,
           direction: nil, payload: nil, protocol: 'iso15693')
    { 'delivery_id' => delivery, 'role' => role, 'protocol' => protocol,
      'uid_raw_hex' => uid, 'payload_hex' => payload,
      'device_direction_raw' => direction, 'device_time_raw_hex' => nil,
      'device_record_seq' => seq, 'flags_raw' => {},
      'captured_at' => at.respond_to?(:iso8601) ? at.iso8601(6) : at }
  end

  def observe(items)
    post '/v1/rfid/observations', params: { observations: items }, headers: headers, as: :json
  end

  def results
    body['results']
  end

  def stored(delivery)
    Rfid::Observation.find_by(event: event, delivery_id: delivery)
  end

  before { gate }

  describe 'batch handling' do
    it 'refuses more than fifty entries before saving anything' do
      expect { observe(Array.new(51) { item }) }.not_to change(Rfid::Observation, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('batch_too_large')
      expect(body.keys).to contain_exactly('error', 'message', 'holder', 'binding')
    end

    it 'refuses a malformed entry before saving anything' do
      good = item
      bad = [
        item(role: 'sideways'),
        item(uid: 'XYZ'),
        item(uid: ''),
        item(at: 'yesterday'),
        item(delivery: 'not-a-uuid'),
        item(protocol: 'nfc'),
        item(seq: -1),
        item(direction: 999),
        item(payload: 'ABC')
      ]

      bad.each do |payload|
        expect { observe([good, payload]) }.not_to change(Rfid::Observation, :count)

        expect(response).to have_http_status(:bad_request), payload.inspect
        expect(body['error']).to eq('malformed'), payload.inspect
      end
    end

    it 'stores full unsigned 64-bit device sequence without overflow' do
      observe([item(seq: 2**64 - 1)])

      expect(response).to have_http_status(:ok)
      expect(stored(results[0]['delivery_id']).device_record_seq).to eq(2**64 - 1)
    end

    it 'answers one result per entry, in order, and stores the raw evidence' do
      first = item(at: base, direction: 0, seq: 7, payload: nil)
      second = item(uid: other_tag, role: 'exit', at: base + 1.minute)

      observe([first, second])

      expect(response).to have_http_status(:ok)
      expect(results.map { |r| r['delivery_id'] })
        .to eq([first['delivery_id'], second['delivery_id']])
      expect(results.map { |r| r['outcome'] }).to eq(%w[unknown_tag unknown_tag])
      expect(results[0]['display']['reason']).to be_present
      expect(results[0]['anomalies']).to eq([])

      row = stored(first['delivery_id'])
      expect(row).to have_attributes(role: 'entry', protocol: 'iso15693', uid_raw_hex: tag,
                                     tag_key: tag, device_record_seq: 7, outcome: 'unknown_tag',
                                     anomalies: [])
      expect(row.device_metadata['device_direction_raw']).to eq(0)
      expect(row.original_response['outcome']).to eq('unknown_tag')
      expect(row.ticket_id).to be_nil
      expect(row.captured_at).to eq(base)
      expect(row.station_id).to eq(Rfid::Station.find_by(station_key: station_key).id)
    end

    it 'needs a heartbeated station and the rfid key' do
      post '/v1/rfid/observations', params: { observations: [item] },
                                    headers: { 'Authorization' => key.raw_key.to_s,
                                               'X-RfiDex-Station' => 'never-seen' },
                                    as: :json
      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')

      post '/v1/rfid/observations', params: { observations: [item] },
                                    headers: { 'Authorization' => key.raw_key,
                                               'X-RfiDex-Station' => station_key }.merge({}),
                                    as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'replay' do
    it 'keeps the original answer after a late binding, and refuses new content for the id' do
      delivery = SecureRandom.uuid
      observe([item(delivery: delivery)])
      original = results[0]
      expect(original['outcome']).to eq('unknown_tag')

      bind_via_api(tag, at: base - 1.minute)

      expect { observe([item(delivery: delivery)]) }.not_to change(Rfid::Observation, :count)
      expect(response).to have_http_status(:ok)
      expect(results[0]).to eq(original)
      expect(stored(delivery).reload.outcome).to eq('accepted')

      observe([item(delivery: delivery, role: 'exit')])
      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')
    end

    it 'treats the same device sequence from a different delivery as a duplicate' do
      bind(tag)
      observe([item(seq: 44, at: base)])
      expect(results[0]['outcome']).to eq('accepted')

      expect { observe([item(seq: 44, at: base + 1.minute)]) }
        .to change(Rfid::Observation, :count).by(1)

      expect(results[0]['outcome']).to eq('possible_duplicate')
      expect(results[0]['anomalies']).to eq([])
      expect(results[0]['display']).to eq('name' => nil, 'ticket_type' => nil, 'reason' => nil)
      expect(event.rfid_visits.count).to eq(1)
    end
  end

  describe 'outcomes' do
    it 'flags a raw direction that contradicts the configured role' do
      bind(tag)
      observe([item(role: 'exit', direction: 0)])

      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['anomalies']).to eq(['role_mismatch'])
      expect(results[0]['display']['name']).to eq('Ahmad Bin Ali')
    end

    it 'records each passage with the role it was captured under' do
      Rfid::Station.find_by!(event: event, station_key: station_key).update!(role: 'exit')
      bind(tag)

      observe([item(role: 'entry')])

      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['anomalies']).not_to include('role_mismatch')
      expect(Rfid::Observation.last.role).to eq('entry')
      expect(event.rfid_visits.open.count).to eq(1)
    end

    it 'keeps an older binding valid until its later replacement capture' do
      bind(tag, ticket, at: base - 1.hour)
      Rfid::Binding.find_by!(event: event, tag_key: tag).update!(
        revoked_at: Time.current, revocation_reason: 'replacement'
      )
      other = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                     attendee_name: 'Replacement Guest')
      bind(tag, other, at: base + 1.hour)

      observe([item(at: base)])

      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['display']['name']).to eq('Ahmad Bin Ali')
    end

    it 'ends old tag validity at replacement capture, not server arrival' do
      bind(tag, ticket, at: base - 1.hour)
      Rfid::Binding.find_by!(event: event, tag_key: tag).update!(
        revoked_at: Time.current, revocation_reason: 'new sticker'
      )
      bind(other_tag, ticket, at: base + 1.hour)

      observe([item(at: base + 2.hours)])

      expect(results[0]['outcome']).to eq('revoked_tag')
    end

    it 'denies a payload that names a different ticket in the same event' do
      bind(tag)
      mismatched = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                        attendee_name: 'Other Guest')

      observe([item(payload: payload_for(mismatched.public_id))])

      expect(results[0]['outcome']).to eq('ticket_invalid')
      expect(results[0]['anomalies']).to eq(['payload_binding_mismatch'])
      expect(stored(results[0]['delivery_id']).payload_public_id).to eq(mismatched.public_id)
    end

    it 'answers wrong_event for a payload from another event, with no identity' do
      other_event = create(:event, use_api_access: true)
      stranger = create(:ticket, :paid, event: other_event, attendee_name: 'Zara Isolated')
      bind(tag)

      observe([item(payload: payload_for(stranger.public_id))])

      expect(results[0]['outcome']).to eq('wrong_event')
      expect(results[0]['display']).to eq('name' => nil, 'ticket_type' => nil, 'reason' => nil)
      expect(response.body).not_to include('Zara Isolated')
    end

    it 'reports a revoked sticker as revoked and an unknown one as unknown' do
      bind(tag)
      Rfid::Binding.find_by(tag_key: tag)
                   .update!(revoked_at: Time.current, revocation_reason: 'swapped')
      bind(other_tag, at: base + 1.minute)

      observe([item(at: base + 2.minutes), item(uid: '0000000000000001', at: base + 2.minutes)])

      expect(results.map { |r| r['outcome'] }).to eq(%w[revoked_tag unknown_tag])
      expect(results[0]['display']['reason']).to be_present
    end

    it 'denies a ticket that is no longer valid' do
      bind(tag)
      ticket.update_columns(payment_status: Ticket.payment_statuses[:pending])

      observe([item])

      expect(results[0]['outcome']).to eq('ticket_invalid')
      expect(results[0]['display']['name']).to eq('Ahmad Bin Ali')
    end

    it 'accepts an entry without check-in, or denies it when the event requires check-in' do
      bind(tag)
      observe([item])
      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['anomalies']).to eq(['entered_without_check_in'])

      event.update!(rfid_require_check_in: true)
      observe([item(at: base + 1.minute)])
      expect(results[0]['outcome']).to eq('not_checked_in')
      expect(results[0]['anomalies']).to eq([])
    end

    it 'never treats a payload alone as authorization' do
      observe([item(uid: '00000000000000FF', payload: payload_for(ticket.public_id))])

      expect(results[0]['outcome']).to eq('unknown_tag')
      expect(results[0]['display']['name']).to be_nil
    end
  end

  describe 'late binding' do
    it 're-evaluates earlier reads but leaves the original reply and old reads alone' do
      before_binding = item(at: base - 10.minutes, role: 'exit')
      after_binding = item(at: base + 10.minutes, role: 'exit')
      observe([before_binding, after_binding])
      expect(results.map { |r| r['outcome'] }).to eq(%w[unknown_tag unknown_tag])

      # The offline desk's binding arrives after the gate already delivered.
      bind_via_api(tag, at: base)

      expect(stored(before_binding['delivery_id']).reload.outcome).to eq('unknown_tag')
      expect(stored(after_binding['delivery_id']).reload.outcome).to eq('accepted')
      expect(stored(after_binding['delivery_id']).original_response['outcome'])
        .to eq('unknown_tag')

      # Replay still answers what the gate was first told.
      observe([after_binding])
      expect(results[0]['outcome']).to eq('unknown_tag')

      expect(event.rfid_visits.count).to eq(0)
    end

    it 'does not accept a passage before the binding existed, or after its replacement' do
      bind_via_api(tag, at: base)
      replacement_ticket = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                                attendee_name: 'Second Guest')

      early = item(at: base - 1.minute, role: 'exit')
      observe([early])
      expect(results[0]['outcome']).to eq('unknown_tag')

      # The sticker is moved to another guest, captured at base + 1 hour.
      bind_via_api(tag, target: replacement_ticket, at: base + 1.hour,
                   replace: true, reason: 'sticker moved')

      late = item(at: base + 2.hours, role: 'exit')
      observe([late])

      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['display']['name']).to eq('Second Guest')
    end
  end

  describe 'late check-in' do
    it 'accepts a reading once the delayed desk check-in proves the guest was in' do
      bind(tag, at: base - 1.minute)
      entry = item(at: base + 10.minutes)
      observe([entry])
      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['anomalies']).to eq(['entered_without_check_in'])

      # The desk checked the guest in at base, but only delivered it now.
      ScanGate.record!(ticket, source: :rfid_desk, at: base, operation_id: SecureRandom.uuid)
      Rfid::Visits.reconcile_locked!(event: event, ticket_id: ticket.id)

      expect(stored(entry['delivery_id']).reload.outcome).to eq('accepted')
      expect(stored(entry['delivery_id']).reload.anomalies).to eq([])
      expect(stored(entry['delivery_id']).original_response['anomalies'])
        .to eq(['entered_without_check_in'])

      # A reading captured before the check-in still shows the guest was not in.
      earlier = item(at: base - 30.seconds)
      observe([earlier])
      expect(results[0]['outcome']).to eq('accepted')
      expect(results[0]['anomalies']).to eq(['entered_without_check_in'])
    end
  end

  def payload_for(public_id)
    bytes = [0x52, 0x58, 0x01, 0x00] + [public_id.delete('-')].pack('H*').bytes
    bytes[3] = Rfid::Wire.crc8(bytes[4, 16])
    Rfid::Wire.hex_upper(bytes)
  end
end
