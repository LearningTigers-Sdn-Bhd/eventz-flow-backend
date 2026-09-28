require 'rails_helper'

# Plan 5 Task 4: the desk check-in. One operation, one check-in, one webhook —
# and a replay that answers exactly what the first call answered.
RSpec.describe 'V1::Rfid desk scans', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true, webhook_url: 'https://example.com/print') }
  let(:key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:ticket) do
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Ahmad Bin Ali')
  end
  let(:station) { 'desk-contract' }
  let(:headers) { { 'Authorization' => key.raw_key, 'X-RfiDex-Station' => station } }
  let(:captured_at) { Time.zone.parse('2026-09-26T09:14:03Z') }
  let(:operation_id) { '00000000-0000-0000-0000-000000009001' }
  let(:repeat_operation_id) { '00000000-0000-0000-0000-000000009002' }

  def body
    JSON.parse(response.body)
  end

  def scan(public_id, operation: operation_id, at: captured_at)
    post '/v1/rfid/desk_scans',
         params: { public_id: public_id, operation_id: operation, captured_at: at.iso8601(6) },
         headers: headers, as: :json
  end

  def webhook_payloads
    ActiveJob::Base.queue_adapter.enqueued_jobs
                        .select { |job| job[:job] == WebhookSenderJob }
                        .map { |job| job[:args][1].deep_symbolize_keys }
  end

  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  it 'checks the guest in, saves the scan and answers the contract shape' do
    expect { scan(ticket.public_id) }.to change(ScanLog, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(body).to eq(
      'ticket' => { 'public_id' => ticket.public_id, 'name' => 'Ahmad Bin Ali',
                    'ticket_type' => 'Delegate', 'valid' => true, 'checked_in' => true },
      'binding' => nil,
      'check_in' => { 'result' => 'checked_in',
                      'checked_in_at' => '2026-09-26T09:14:03.000000Z' }
    )
    expect(Time.iso8601(body['check_in']['checked_in_at'])).to eq(captured_at)

    log = ScanLog.for_scannable(ticket).sole
    expect(log).to have_attributes(source: 'rfid_desk', operation_id: operation_id,
                                   scanned_at: captured_at)

    ticket.reload
    expect(ticket.checked_in).to be(true)
    expect(ticket.check_in_at).to eq(captured_at)
    expect(ticket.status).to eq('scanned')

    scanned = webhook_payloads.select { |payload| payload[:event_type] == 'ticket.scanned' }
    expect(scanned.length).to eq(1)
    expect(scanned[0][:scan_source]).to eq('rfid_desk')
  end

  it 'includes the active sticker when the ticket already has one' do
    binding = Rfid::Binding.create!(
      event: event, ticket: ticket, ticket_public_id: ticket.public_id,
      ticket_name: ticket.attendee_name, protocol: 'iso15693',
      uid_raw_hex: '3412CDAB500104E0', tag_key: '3412CDAB500104E0', mode: 'bind',
      captured_at: 1.hour.ago, operation_id: SecureRandom.uuid
    )

    scan(ticket.public_id)

    expect(body['binding']).to eq(
      'id' => binding.id, 'public_id' => ticket.public_id, 'protocol' => 'iso15693',
      'uid_raw_hex' => '3412CDAB500104E0', 'tag_key' => '3412CDAB500104E0', 'mode' => 'bind'
    )
  end

  it 'answers already_checked_in for a second operation, without a second log' do
    scan(ticket.public_id)

    expect { scan(ticket.public_id, operation: repeat_operation_id, at: captured_at + 5.minutes) }
      .not_to change(ScanLog, :count)

    expect(response).to have_http_status(:ok)
    expect(body['check_in']).to eq(
      'result' => 'already_checked_in', 'checked_in_at' => body['check_in']['checked_in_at']
    )
    expect(Time.iso8601(body['check_in']['checked_in_at'])).to eq(captured_at)
    expect(ticket.reload.check_in_at).to eq(captured_at)

    scanned = webhook_payloads.select { |payload| payload[:event_type] == 'ticket.scanned' }
    expect(scanned.length).to eq(1)
  end

  it 'replays the first operation with its own answer, after later scans' do
    scan(ticket.public_id)
    first = body
    scan(ticket.public_id, operation: repeat_operation_id, at: captured_at + 5.minutes)

    expect { scan(ticket.public_id) }.not_to change(ScanLog, :count)
    expect(response).to have_http_status(:ok)
    expect(body).to eq(first)
    expect(body['check_in']['result']).to eq('checked_in')

    expect(webhook_payloads.count { |payload| payload[:event_type] == 'ticket.scanned' }).to eq(1)
  end

  it 'rejects changed payload when reusing a blocked repeat operation' do
    scan(ticket.public_id)
    scan(ticket.public_id, operation: repeat_operation_id, at: captured_at + 5.minutes)
    expect(body['check_in']['result']).to eq('already_checked_in')

    other = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                   attendee_name: 'Another Guest')
    scan(other.public_id, operation: repeat_operation_id, at: captured_at + 5.minutes)

    expect(response).to have_http_status(:bad_request)
    expect(body['error']).to eq('malformed')
    expect(other.reload.checked_in).to be(false)
  end

  it 'rejects the same operation id with a different payload as malformed' do
    scan(ticket.public_id)

    other = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                   attendee_name: 'Second Guest')
    scan(other.public_id)

    expect(response).to have_http_status(:bad_request)
    expect(body['error']).to eq('malformed')
    expect(other.reload.checked_in).to be(false)
    expect(ScanLog.for_scannable(other)).to be_empty
  end

  it 'treats a guest checked in before the event as already checked in' do
    imported = create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                                   attendee_name: 'Imported Guest',
                                                   check_in_at: 2.days.ago)

    scan(imported.public_id)

    expect(response).to have_http_status(:ok)
    expect(body['check_in']['result']).to eq('already_checked_in')
    expect(Time.iso8601(body['check_in']['checked_in_at']))
      .to be_within(1.second).of(imported.check_in_at)
    expect(webhook_payloads.count { |payload| payload[:event_type] == 'ticket.scanned' }).to eq(0)
  end

  it 'lets an unlimited event record later scans but never reprints the first one' do
    event.update!(multiple_scans: true, multiple_scan_mode: :unlimited)
    scan(ticket.public_id)

    expect { scan(ticket.public_id, operation: repeat_operation_id, at: captured_at + 1.hour) }
      .to change(ScanLog, :count).by(1)

    expect(body['check_in']['result']).to eq('already_checked_in')
    expect(Time.iso8601(body['check_in']['checked_in_at'])).to eq(captured_at)
    expect(ticket.reload.check_in_at).to eq(captured_at)
  end

  it 'rejects unpaid, cancelled and unknown tickets with typed errors' do
    unpaid = create(:ticket, event: event, ticket_type: ticket_type, attendee_name: 'Unpaid Guest')
    cancelled = create(:ticket, :paid, event: event, ticket_type: ticket_type,
                                        attendee_name: 'Cancelled Guest', status: :canceled)
    other_event = create(:event, use_api_access: true)
    stranger = create(:ticket, :paid, event: other_event, attendee_name: 'Other Event')

    [
      [unpaid.public_id, 422, 'ticket_unpaid'],
      [cancelled.public_id, 422, 'ticket_cancelled'],
      [SecureRandom.uuid, 404, 'ticket_not_found'],
      [stranger.public_id, 404, 'ticket_not_found']
    ].each do |public_id, status, error|
      scan(public_id)

      expect(response).to have_http_status(status), error
      expect(body['error']).to eq(error)
      expect(body.keys).to contain_exactly('error', 'message', 'holder', 'binding')
    end

    expect(ScanLog.where(event: event).count).to eq(0)
    expect(stranger.reload.checked_in).to be(false)
  end

  it 'rejects a malformed body without touching anything' do
    [
      { public_id: 'not-a-uuid', operation_id: operation_id, captured_at: captured_at.iso8601 },
      { public_id: ticket.public_id, operation_id: 'not-a-uuid', captured_at: captured_at.iso8601 },
      { public_id: ticket.public_id, operation_id: operation_id, captured_at: 'yesterday' },
      { public_id: ticket.public_id, operation_id: operation_id }
    ].each do |payload|
      post '/v1/rfid/desk_scans', params: payload, headers: headers, as: :json

      expect(response).to have_http_status(:bad_request), payload.inspect
      expect(body['error']).to eq('malformed'), payload.inspect
    end

    expect(ScanLog.where(event: event).count).to eq(0)
    expect(ticket.reload.checked_in).to be(false)
  end

  it 'needs the rfid key, the station header and the key event' do
    post '/v1/rfid/desk_scans',
         params: { public_id: ticket.public_id, operation_id: operation_id, captured_at: captured_at.iso8601 },
         headers: { 'Authorization' => key.raw_key }, as: :json
    expect(response).to have_http_status(:bad_request)

    post '/v1/rfid/desk_scans',
         params: { public_id: ticket.public_id, operation_id: operation_id, captured_at: captured_at.iso8601 },
         headers: { 'X-RfiDex-Station' => station }, as: :json
    expect(response).to have_http_status(:unauthorized)

    other_event = create(:event, use_api_access: true)
    other_key = create(:api_key, user: owner, event: other_event, scope: 'rfid')
    post '/v1/rfid/desk_scans',
         params: { public_id: ticket.public_id, operation_id: operation_id, captured_at: captured_at.iso8601 },
         headers: { 'Authorization' => other_key.raw_key, 'X-RfiDex-Station' => station }, as: :json
    expect(response).to have_http_status(:not_found)

    expect(ticket.reload.checked_in).to be(false)
  end
end
