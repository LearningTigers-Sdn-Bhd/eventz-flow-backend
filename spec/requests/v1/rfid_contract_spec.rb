require 'rails_helper'

# Plan 5 Task 8: one place that pins the whole device contract — exact DTO
# fields, error spellings, and the flows the RfiDex contract tests assert —
# plus the staff-facing side effects they imply.
RSpec.describe 'RfiDex backend contract', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true, webhook_url: 'https://example.com/print') }
  let(:other_event) { create(:event, use_api_access: true) }
  let(:key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let(:other_key) { create(:api_key, user: owner, event: other_event, scope: 'rfid') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:station) { 'desk-contract' }
  let(:headers) { { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station } }
  let(:tag) { '3412CDAB500104E0' }
  let(:captured_at) { Time.zone.parse('2026-09-26T09:14:03Z') }
  let(:ticket) do
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Ahmad Bin Ali',
                            attendee_email: 'Ahmad@Example.com', attendee_phone: '012-345 6789')
  end

  def body
    JSON.parse(response.body)
  end

  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  def heartbeat(kind: 'desk', role: nil)
    post '/v1/rfid/stations/heartbeat',
         params: { name: 'Station', kind: kind, role: role, hw_model: nil, firmware: nil,
                   app_version: '0.3.0' }, headers: headers, as: :json
  end

  def desk_scan(operation_id: SecureRandom.uuid, at: captured_at)
    post '/v1/rfid/desk_scans',
         params: { public_id: ticket.public_id, operation_id: operation_id,
                   captured_at: at.iso8601(6) }, headers: headers, as: :json
  end

  def bind_sticker(uid: tag, target: ticket, at: captured_at)
    post '/v1/rfid/bindings',
         params: { public_id: target.public_id, protocol: 'iso15693', uid_raw_hex: uid,
                   mode: 'bind', payload_version: nil, operation_id: SecureRandom.uuid,
                   captured_at: at.iso8601(6), replace: false, reason: nil },
         headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
  end

  def observe(items)
    post '/v1/rfid/observations', params: { observations: items }, headers: headers, as: :json
  end

  def reading(role, at, uid: tag, delivery: SecureRandom.uuid)
    { 'delivery_id' => delivery, 'role' => role, 'protocol' => 'iso15693', 'uid_raw_hex' => uid,
      'payload_hex' => nil, 'device_direction_raw' => nil, 'device_time_raw_hex' => nil,
      'device_record_seq' => nil, 'flags_raw' => {}, 'captured_at' => at.iso8601(6) }
  end

  describe 'response shapes' do
    it 'answers each device route with exactly the fields rfidex-core declares' do
      ticket
      heartbeat

      expect(body.keys).to contain_exactly('event', 'uid_rule', 'server_time')
      expect(body['event'].keys).to contain_exactly('event_id', 'name', 'rfid_mode',
                                                    'require_check_in')

      get '/v1/rfid/cache', headers: headers
      expect(body.keys).to contain_exactly('tickets', 'bindings', 'revoked_tag_keys', 'server_time')
      expect(body['tickets'][0].keys).to contain_exactly('public_id', 'name', 'ticket_type',
                                                         'valid', 'checked_in')

      get '/v1/rfid/tickets/search', params: { by: 'name', q: 'ahmad' }, headers: headers
      expect(body.keys).to contain_exactly('tickets')
      expect(body['tickets'][0].keys).to contain_exactly(
        'public_id', 'name', 'ticket_type', 'valid', 'checked_in', 'checked_in_at',
        'email_hint', 'phone_hint'
      )

      desk_scan
      expect(body.keys).to contain_exactly('ticket', 'binding', 'check_in')
      expect(body['check_in'].keys).to contain_exactly('result', 'checked_in_at')

      bind_sticker
      expect(body.keys).to contain_exactly('binding', 'revoked')
      expect(body['binding'].keys).to contain_exactly('id', 'public_id', 'protocol',
                                                      'uid_raw_hex', 'tag_key', 'mode')

      get '/v1/rfid/bindings/lookup', params: { uid_raw_hex: tag }, headers: headers
      expect(body.keys).to contain_exactly('binding', 'holder')
      expect(body['holder'].keys).to contain_exactly('public_id', 'name', 'ticket_type', 'valid',
                                                     'checked_in')

      observe([reading('exit', captured_at)])
      expect(body.keys).to contain_exactly('results')
      expect(body['results'][0].keys).to contain_exactly('delivery_id', 'outcome', 'anomalies',
                                                         'display')
      expect(body['results'][0]['display'].keys).to contain_exactly('name', 'ticket_type', 'reason')
    end

    it 'answers every device error with all four nullable fields' do
      post '/v1/rfid/desk_scans', params: { public_id: SecureRandom.uuid,
                                            operation_id: SecureRandom.uuid,
                                            captured_at: captured_at.iso8601(6) },
                                  headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(body).to include('error' => 'ticket_not_found', 'holder' => nil, 'binding' => nil)
      expect(body.keys).to contain_exactly('error', 'message', 'holder', 'binding')
    end
  end

  describe 'the flows the portable contract asserts' do
    before { heartbeat }
    it 'records the source of the check-in on the webhook exactly once' do
      first_operation_id = SecureRandom.uuid
      desk_scan(operation_id: first_operation_id)
      first = body

      desk_scan
      expect(body['check_in']['result']).to eq('already_checked_in')

      desk_scan(operation_id: first_operation_id)
      expect(body).to eq(first)

      payloads = ActiveJob::Base.queue_adapter.enqueued_jobs
                              .select { |job| job[:job] == WebhookSenderJob }
                              .map { |job| job[:args][1].deep_symbolize_keys }
                              .select { |payload| payload[:event_type] == 'ticket.scanned' }
      expect(payloads.length).to eq(1)
      expect(payloads[0][:scan_source]).to eq('rfid_desk')
      expect(ScanLog.where(event: event).count).to eq(1)
    end

    it 'never puts a full contact in a search or a cache reply' do
      ticket

      get '/v1/rfid/tickets/search', params: { by: 'name', q: 'ahmad' }, headers: headers
      expect(body['tickets'][0]['email_hint']).to eq('ah***@example.com')
      expect(body['tickets'][0]['phone_hint']).to eq('•••• 6789')
      expect(response.body).not_to include('ahmad@example.com')
      expect(response.body).not_to include('Ahmad@Example.com')
      expect(response.body).not_to include('0123456789')

      get '/v1/rfid/cache', headers: headers
      expect(response.body).not_to include('hint', 'email', 'phone')
    end

    it 'corrects a gate reading once the offline desk binding arrives' do
      # The gate reads first; the desk's binding was captured an hour earlier,
      # but the server only hears about it after the reading arrived.
      read_at = captured_at
      delivery = SecureRandom.uuid
      observe([reading('exit', read_at, delivery: delivery)])
      expect(body['results'][0]['outcome']).to eq('unknown_tag')

      bind_sticker(at: captured_at - 1.hour)

      row = Rfid::Observation.find_by(delivery_id: delivery).reload
      expect(row.outcome).to eq('accepted')
      expect(row.original_response['outcome']).to eq('unknown_tag')

      # Replaying the delivery still returns the reply the gate was first given.
      observe([reading('exit', read_at, delivery: delivery)])
      expect(body['results'][0]['outcome']).to eq('unknown_tag')
    end

    it 'refuses a sticker guessed from another event and a station that is not ours' do
      stranger = create(:ticket, :paid, event: other_event, attendee_name: 'Zara Isolated')

      post '/v1/rfid/desk_scans',
           params: { public_id: stranger.public_id, operation_id: SecureRandom.uuid,
                     captured_at: captured_at.iso8601(6) },
           headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('ticket_not_found')

      # The other event's key, with this event's guessed ticket id, sees nothing.
      post '/v1/rfid/desk_scans',
           params: { public_id: ticket.public_id, operation_id: SecureRandom.uuid,
                     captured_at: captured_at.iso8601(6) },
           headers: { 'Authorization' => other_key.raw_key, 'X-RfiDex-Station' => station },
           as: :json
      expect(response).to have_http_status(:not_found)

      # A tag bound in the other event is invisible and unbound here.
      Rfid::Binding.create!(event: other_event, ticket: stranger,
                            ticket_public_id: stranger.public_id, ticket_name: stranger.attendee_name,
                            protocol: 'iso15693', uid_raw_hex: tag, tag_key: tag, mode: 'bind',
                            captured_at: captured_at, operation_id: SecureRandom.uuid)
      get '/v1/rfid/bindings/lookup', params: { uid_raw_hex: tag }, headers: headers
      expect(body).to eq('binding' => nil, 'holder' => nil)

      # A desk scan in this event still works, so the guard is per key.
      desk_scan
      expect(response).to have_http_status(:ok)
    end
  end
end
