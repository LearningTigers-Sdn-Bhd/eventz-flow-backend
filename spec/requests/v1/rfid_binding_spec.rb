require 'rails_helper'

# Plan 5 Task 5: the sticker binding. First committed binding wins, a conflict
# never leaks a holder outside the keyed event, and a replay answers what the
# original operation answered.
RSpec.describe 'V1::Rfid bindings', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true) }
  let(:key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:ticket) do
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Ahmad Bin Ali')
  end
  let(:other_ticket) do
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Siti Nurhaliza')
  end
  let(:station_key) { 'desk-contract' }
  let(:headers) { { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station_key } }
  let(:tag) { '3412CDAB500104E0' }
  let(:other_tag) { 'AABBCCDD00112233' }
  let(:captured_at) { Time.zone.parse('2026-09-26T09:14:03Z') }

  def body
    JSON.parse(response.body)
  end

  def bind(target = ticket, uid: tag, operation: SecureRandom.uuid, mode: 'bind',
           payload_version: nil, replace: false, reason: nil, protocol: 'iso15693',
           at: captured_at, public_id: nil)
    post '/v1/rfid/bindings',
         params: { public_id: public_id || target.public_id, protocol: protocol,
                   uid_raw_hex: uid, mode: mode, payload_version: payload_version,
                   operation_id: operation,
                   captured_at: at.respond_to?(:iso8601) ? at.iso8601(6) : at,
                   replace: replace, reason: reason },
         headers: headers, as: :json
  end

  def active_bindings
    Rfid::Binding.active.where(event: event)
  end

  describe 'a first binding' do
    it 'creates one active binding and answers the contract shape' do
      expect { bind }.to change { active_bindings.count }.by(1)

      expect(response).to have_http_status(:created)
      binding = active_bindings.sole
      expect(body).to eq(
        'binding' => { 'id' => binding.id, 'public_id' => ticket.public_id,
                       'protocol' => 'iso15693', 'uid_raw_hex' => tag, 'tag_key' => tag,
                       'mode' => 'bind' },
        'revoked' => []
      )
      expect(binding).to have_attributes(ticket_id: ticket.id, ticket_name: 'Ahmad Bin Ali',
                                         ticket_public_id: ticket.public_id,
                                         payload_version: nil, revoked_at: nil)
    end

    it 'normalises the raw UID to the spelling the contract uses' do
      bind(uid: '3412cdab500104e0')

      expect(body['binding']['uid_raw_hex']).to eq(tag)
      expect(body['binding']['tag_key']).to eq(tag)
    end

    it 'applies the station UID rule to the canonical key but never to the raw bytes' do
      Rfid::Station.create!(event: event, station_key: station_key, kind: 'desk',
                            uid_rule: 'reversed')

      bind(uid: '3412CDAB500104E0')

      expect(body['binding']['tag_key']).to eq('E0040150ABCD1234')
      expect(body['binding']['uid_raw_hex']).to eq('3412CDAB500104E0')
    end

    it 'defaults to as_is for a station that has not heartbeated yet' do
      bind

      expect(response).to have_http_status(:created)
      expect(body['binding']['tag_key']).to eq(tag)
    end
  end

  describe 'replay and repeats' do
    it 'replays an operation with the same answer and no second row' do
      operation = SecureRandom.uuid
      bind(operation: operation)
      first = body

      expect { bind(operation: operation) }.not_to change(Rfid::Binding, :count)

      expect(response).to have_http_status(:ok)
      expect(body).to eq(first)
      expect(Rfid::BindingOperation.where(event: event).count).to eq(1)
    end

    it 'answers a new operation for the same pair without a second row' do
      bind
      first = body

      expect { bind }.not_to change(Rfid::Binding, :count)

      expect(response).to have_http_status(:ok)
      expect(body).to eq(first)
      expect(Rfid::BindingOperation.where(event: event).count).to eq(2)
    end

    it 'refuses the same operation id with different content' do
      operation = SecureRandom.uuid
      bind(operation: operation)

      bind(other_ticket, operation: operation)

      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')
      expect(active_bindings.count).to eq(1)
      expect(Rfid::Binding.where(ticket: other_ticket)).to be_empty
    end
  end

  describe 'conflicts' do
    it 'refuses a sticker that is on another ticket and names the holder' do
      bind
      owner_binding = active_bindings.sole

      expect { bind(other_ticket) }.not_to change(Rfid::Binding, :count)

      expect(response).to have_http_status(:conflict)
      expect(body['error']).to eq('uid_bound_elsewhere')
      expect(body['holder']).to eq(
        'public_id' => ticket.public_id, 'name' => 'Ahmad Bin Ali', 'ticket_type' => 'Delegate',
        'valid' => true, 'checked_in' => false
      )
      expect(body['binding']['id']).to eq(owner_binding.id)
    end

    it 'refuses a second sticker for a ticket that already has one' do
      bind
      own_binding = active_bindings.sole

      expect { bind(ticket, uid: other_tag) }.not_to change(Rfid::Binding, :count)

      expect(response).to have_http_status(:conflict)
      expect(body['error']).to eq('ticket_has_sticker')
      expect(body['holder']).to be_nil
      expect(body['binding']['id']).to eq(own_binding.id)
    end

    it 'requires a trimmed, non-empty reason to replace' do
      bind

      [nil, '', '   '].each do |reason|
        expect { bind(other_ticket, replace: true, reason: reason) }
          .not_to change(Rfid::Binding, :count)

        expect(response).to have_http_status(:unprocessable_content), reason.inspect
        expect(body['error']).to eq('reason_required'), reason.inspect
      end
    end

    it 'never leaks a holder from another event' do
      other_event = create(:event, use_api_access: true)
      other_key = create(:api_key, user: owner, event: other_event, scope: 'rfid')
      stranger = create(:ticket, :paid, event: other_event, attendee_name: 'Zara Isolated')
      Rfid::Binding.create!(event: other_event, ticket: stranger,
                            ticket_public_id: stranger.public_id, ticket_name: stranger.attendee_name,
                            protocol: 'iso15693', uid_raw_hex: tag, tag_key: tag,
                            mode: 'bind', captured_at: 1.minute.ago,
                            operation_id: SecureRandom.uuid)

      # The same sticker key may be in use in two events; the other event's
      # holder neither blocks nor appears here.
      bind(ticket, uid: tag)

      expect(response).to have_http_status(:created)
      expect(body['binding']['public_id']).to eq(ticket.public_id)

      # A conflict inside this event names this event's guest, and only them.
      bind(other_ticket, uid: tag)

      expect(response).to have_http_status(:conflict)
      expect(body['holder']['public_id']).to eq(ticket.public_id)
      expect(body['holder']['name']).not_to eq('Zara Isolated')
      expect(response.body).not_to include('Zara Isolated')

      # And the other event still answers for its own guest.
      get '/v1/rfid/bindings/lookup', params: { uid_raw_hex: tag },
                                      headers: { 'Authorization' => other_key.raw_key,
                                                 'X-RfiDex-Station' => station_key }
      expect(body['holder']['public_id']).to eq(stranger.public_id)
    end
  end

  describe 'replacement' do
    it 'revokes the old binding and keeps the history' do
      bind
      old = active_bindings.sole

      bind(other_ticket, replace: true, reason: 'wrong sticker on the badge')

      expect(response).to have_http_status(:created)
      expect(body['revoked'].length).to eq(1)
      expect(body['revoked'][0]['id']).to eq(old.id)
      expect(old.reload.revoked_at).to be_present
      expect(old.revocation_reason).to eq('wrong sticker on the badge')
      expect(body['binding']['public_id']).to eq(other_ticket.public_id)
      expect(active_bindings.count).to eq(1)
      expect(Rfid::Binding.where(event: event).count).to eq(2)
    end

    it 'keeps first committed winner for readings after an earlier-captured replacement' do
      bind(ticket, at: Time.zone.parse('2026-09-26T10:00:00Z'))
      bind(other_ticket, at: Time.zone.parse('2026-09-26T08:00:00Z'), replace: true,
                         reason: 'desk correction')
      station = Rfid::Station.create!(event: event, station_key: 'replacement-gate',
                                                   kind: 'gate', role: 'entry')
      reading = Rfid::Observe::Item.new(
        delivery_id: SecureRandom.uuid, role: 'entry', protocol: 'iso15693',
        uid_raw_hex: tag, tag_key: tag, payload_hex: nil, payload_public_id: nil,
        device_direction_raw: nil, device_time_raw_hex: nil, device_record_seq: nil,
        flags_raw: {}, captured_at: Time.zone.parse('2026-09-26T11:00:00Z')
      )

      result = Rfid::Observe.call(event: event, station: station, items: [reading]).sole

      expect(result['display']['name']).to eq(other_ticket.attendee_name)
    end

    it 'uses replacement when old and new bindings share capture time' do
      captured = Time.zone.parse('2026-09-26T10:00:00Z')
      bind(ticket, at: captured)
      bind(other_ticket, at: captured, replace: true, reason: 'corrected tag owner')
      station = Rfid::Station.create!(event: event, station_key: 'same-time-gate',
                                                   kind: 'gate', role: 'entry')
      reading = Rfid::Observe::Item.new(
        delivery_id: SecureRandom.uuid, role: 'entry', protocol: 'iso15693',
        uid_raw_hex: tag, tag_key: tag, payload_hex: nil, payload_public_id: nil,
        device_direction_raw: nil, device_time_raw_hex: nil, device_record_seq: nil,
        flags_raw: {}, captured_at: captured
      )

      result = Rfid::Observe.call(event: event, station: station, items: [reading]).sole

      expect(result['display']['name']).to eq(other_ticket.attendee_name)
    end

    it 'revokes both the tag holder and the ticket own sticker when both conflict' do
      bind(ticket, uid: tag)
      tag_binding = active_bindings.sole
      bind(other_ticket, uid: other_tag)
      own_binding = active_bindings.find_by(ticket: other_ticket)

      bind(other_ticket, uid: tag, replace: true, reason: 'moved to the new sticker')

      expect(response).to have_http_status(:created)
      expect(body['revoked'].map { |r| r['id'] }).to contain_exactly(tag_binding.id, own_binding.id)
      expect(active_bindings.count).to eq(1)
      expect(active_bindings.sole.ticket_public_id).to eq(other_ticket.public_id)
    end

    it 'lets a revoked sticker be reused by another ticket' do
      bind
      bind(other_ticket, replace: true, reason: 'sticker moved')

      bind(ticket, uid: other_tag)

      expect(response).to have_http_status(:created)
      expect(active_bindings.count).to eq(2)
    end
  end

  describe 'the first committed binding wins' do
    it 'refuses a conflicting request even when its capture time is earlier' do
      bind(other_ticket, uid: tag, at: 2.hours.ago)

      bind(ticket, uid: tag, at: 3.hours.ago)

      expect(response).to have_http_status(:conflict)
      expect(body['error']).to eq('uid_bound_elsewhere')
      expect(Rfid::Binding.active.sole.ticket_public_id).to eq(other_ticket.public_id)
    end

    it 'serialises two service calls that race for the same sticker' do
      operation_ids = [SecureRandom.uuid, SecureRandom.uuid]
      targets = [ticket, other_ticket]

      results = [0, 1].map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Rfid::Bind.call(
              event: event,
              station: nil,
              request: Rfid::Bind::Request.new(public_id: targets[i].public_id,
                                               protocol: 'iso15693', uid_raw_hex: tag,
                                               mode: 'bind', payload_version: nil,
                                               operation_id: operation_ids[i],
                                               captured_at: Time.current, replace: false,
                                               reason: nil)
            )
          end
        end
      end.map(&:value)

      expect(results.count { |status, _| status == 201 }).to eq(1)
      expect(results.count { |status, _| status == 409 }).to eq(1)
      expect(Rfid::Binding.active.where(event: event, tag_key: tag).count).to eq(1)
    end
  end

  describe 'invalid input' do
    it 'rejects unknown protocols, bad hex, bad modes and bad payload versions' do
      cases = [
        { protocol: 'nfc' },
        { uid: '' },
        { uid: 'ABC' },
        { uid: 'XYZ1' },
        { uid: 'AA' * 40 },
        { mode: 'write' },
        { mode: 'written', payload_version: nil },
        { mode: 'written', payload_version: 2 },
        { mode: 'bind', payload_version: 1 },
        { public_id: 'not-a-uuid' },
        { operation: 'not-a-uuid' },
        { at: 'yesterday' }
      ]

      cases.each do |overrides|
        bind(ticket, **overrides)

        expect(response).to have_http_status(:bad_request), overrides.inspect
        expect(body['error']).to eq('malformed'), overrides.inspect
      end

      expect(Rfid::Binding.count).to eq(0)
      expect(Rfid::BindingOperation.count).to eq(0)
    end

    it 'accepts a written sticker with payload version 1' do
      bind(ticket, mode: 'written', payload_version: 1)

      expect(response).to have_http_status(:created)
      expect(body['binding']['mode']).to eq('written')
      expect(active_bindings.sole.payload_version).to eq(1)
    end

    it 'rejects unpaid, cancelled and cross-event tickets' do
      unpaid = create(:ticket, event: event, ticket_type: ticket_type, attendee_name: 'Unpaid Guest')
      cancelled = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                        attendee_name: 'Cancelled Guest', status: :canceled)
      other_event = create(:event, use_api_access: true)
      stranger = create(:ticket, :paid, event: other_event, attendee_name: 'Other Event Guest')

      [[unpaid, 422, 'ticket_unpaid'],
       [cancelled, 422, 'ticket_cancelled'],
       [stranger, 404, 'ticket_not_found']].each do |target, status, error|
        bind(target)

        expect(response).to have_http_status(status), error
        expect(body['error']).to eq(error)
        expect(body.keys).to contain_exactly('error', 'message', 'holder', 'binding')
      end

      expect(Rfid::Binding.count).to eq(0)
    end
  end

  describe 'GET /v1/rfid/bindings/lookup' do
    def lookup(uid, protocol: nil)
      params = { uid_raw_hex: uid }
      params[:protocol] = protocol if protocol
      get '/v1/rfid/bindings/lookup', params: params, headers: headers
    end

    it 'reports the active binding and its holder' do
      bind

      lookup(tag.downcase)

      expect(response).to have_http_status(:ok)
      expect(body['binding']['tag_key']).to eq(tag)
      expect(body['holder']).to eq(
        'public_id' => ticket.public_id, 'name' => 'Ahmad Bin Ali', 'ticket_type' => 'Delegate',
        'valid' => true, 'checked_in' => false
      )
    end

    it 'reports nulls for an unknown, revoked or other-event sticker' do
      lookup(tag)
      expect(body).to eq('binding' => nil, 'holder' => nil)

      bind
      bind(ticket, uid: other_tag, replace: true, reason: 'new sticker')

      lookup(tag)
      expect(body).to eq('binding' => nil, 'holder' => nil)

      other_event = create(:event, use_api_access: true)
      other_key = create(:api_key, user: owner, event: other_event, scope: 'rfid')
      get '/v1/rfid/bindings/lookup', params: { uid_raw_hex: other_tag },
                                      headers: { 'Authorization' => other_key.raw_key,
                                                 'X-RfiDex-Station' => station_key }
      expect(body).to eq('binding' => nil, 'holder' => nil)
    end

    it 'requires a supplied protocol to match the active binding' do
      bind

      lookup(tag, protocol: 'iso15693')
      expect(body['binding']).to be_present

      lookup(tag, protocol: 'iso14443a')
      expect(body).to eq('binding' => nil, 'holder' => nil)

      lookup(tag, protocol: 'nfc')
      expect(response).to have_http_status(:bad_request)
      expect(body['error']).to eq('malformed')
    end

    it 'converts the raw UID with the station rule before looking up' do
      Rfid::Station.create!(event: event, station_key: station_key, kind: 'desk',
                            uid_rule: 'reversed')
      bind(uid: tag)

      expect(body['binding']['uid_raw_hex']).to eq(tag)
      expect(body['binding']['tag_key']).to eq('E0040150ABCD1234')

      lookup(tag)

      expect(response).to have_http_status(:ok)
      expect(body['binding']['tag_key']).to eq('E0040150ABCD1234')
    end

    it 'needs the rfid key and station header' do
      get '/v1/rfid/bindings/lookup', params: { uid_raw_hex: tag }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
