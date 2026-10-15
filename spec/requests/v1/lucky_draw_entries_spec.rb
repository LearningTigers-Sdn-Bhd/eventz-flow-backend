require 'rails_helper'

RSpec.describe 'V1::LuckyDraw entries', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:session) { create(:lucky_draw_session, event: event, created_by: org_owner, scanned_source: 'entries') }
  let!(:entered) { create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Entered') }
  let!(:other) { create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Other', checked_in: true) }
  let(:base) { "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}" }

  it 'records an entry from the ticket QR and rejects a repeat' do
    post "#{base}/entries", params: { public_id: entered.public_id }, headers: headers
    expect(response).to have_http_status(:created)
    expect(LuckyDrawEntry.last.scanned_by).to eq(org_owner)

    post "#{base}/entries", params: { public_id: entered.public_id }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(LuckyDrawEntry.count).to eq(1)
  end

  it 'lists only the latest entries with the full total' do
    tickets = create_list(:ticket, 3, :paid, event: event, ticket_type: ticket_type)
    tickets.each { |t| post "#{base}/entries", params: { public_id: t.public_id }, headers: headers }

    get "#{base}/entries", params: { limit: 2 }, headers: headers
    body = JSON.parse(response.body)
    expect(body['data'].size).to eq(2)
    expect(body['meta']['total']).to eq(3)
    expect(body['data'].first['participant_id']).to eq(tickets.last.id)
  end

  it 'returns not found for an unknown QR' do
    post "#{base}/entries", params: { public_id: SecureRandom.uuid }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'limits the draw pool to entry-scanned tickets only' do
    post "#{base}/entries", params: { public_id: entered.public_id }, headers: headers
    get "#{base}/participants", headers: headers
    names = JSON.parse(response.body)['data'].map { |p| p['name'] }
    expect(names).to contain_exactly('Entered')
  end

  it 'rejects unpaid and canceled tickets' do
    unpaid = create(:ticket, :paid, event: event, ticket_type: ticket_type, payment_status: :pending)
    canceled = create(:ticket, :paid, event: event, ticket_type: ticket_type, status: :canceled)

    [unpaid, canceled].each do |t|
      post "#{base}/entries", params: { public_id: t.public_id }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(LuckyDrawEntry.count).to eq(0)
  end

  it 'rejects a ticket from another event' do
    foreign = create(:ticket, :paid, ticket_type: create(:ticket_type), event: create(:event, use_ticket: true))
    post "#{base}/entries", params: { public_id: foreign.public_id }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'lets visitor events enter by visitor public_id' do
    v_event = create(:event, use_ticket: false)
    v_session = create(:lucky_draw_session, event: v_event, created_by: org_owner, scanned_source: 'entries')
    visitor = create(:visitor, event: v_event)
    post "/v1/events/#{v_event.id}/lucky_draw/sessions/#{v_session.id}/entries",
         params: { public_id: visitor.public_id }, headers: headers
    expect(response).to have_http_status(:created)
    expect(LuckyDrawEntry.last.visitor).to eq(visitor)
  end

  it 'still excludes gift winners from the entry pool when gifts are on' do
    gift_session = create(:lucky_draw_session, event: event, created_by: org_owner,
                                               scanned_source: 'entries', use_gifts: true)
    gift = create(:gift, lucky_draw_session: gift_session)
    other_entered = create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Still In')
    [entered, other_entered].each do |t|
      post "/v1/events/#{event.id}/lucky_draw/sessions/#{gift_session.id}/entries",
           params: { public_id: t.public_id }, headers: headers
    end
    create(:gift_winner, :with_ticket, gift: gift, ticket: entered)

    get "/v1/events/#{event.id}/lucky_draw/sessions/#{gift_session.id}/participants", headers: headers
    expect(JSON.parse(response.body)['data'].map { |p| p['name'] }).to contain_exactly('Still In')
  end

  it 'does not block deleting a ticket or the session' do
    post "#{base}/entries", params: { public_id: entered.public_id }, headers: headers
    entered.destroy!
    expect(LuckyDrawEntry.count).to eq(0)

    post "#{base}/entries", params: { public_id: other.public_id }, headers: headers
    expect { session.destroy! }.to change(LuckyDrawEntry, :count).by(-1)
  end

  it 'refuses users without access to the draw session' do
    outsider = create(:user)
    outsider_headers = { 'Authorization' => "Bearer #{JwtService.generate_tokens(outsider)[:access_token]}" }

    post "#{base}/entries", params: { public_id: entered.public_id }, headers: outsider_headers
    expect(response).to have_http_status(:forbidden)
    get "#{base}/entries", headers: outsider_headers
    expect(response).to have_http_status(:forbidden)
    expect(LuckyDrawEntry.count).to eq(0)
  end
end
