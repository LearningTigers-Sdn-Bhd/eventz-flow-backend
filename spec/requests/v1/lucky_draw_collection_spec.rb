require 'rails_helper'

RSpec.describe 'Lucky draw shared collection records', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:session) { create(:lucky_draw_session, event: event, created_by: owner) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) { create(:ticket, :paid, event: event, ticket_type: ticket_type) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(owner)[:access_token]}" } }
  let(:base) { "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}" }

  def data
    JSON.parse(response.body)['data']
  end

  shared_examples 'shared collection' do
    it 'persists claim and gift, visible through a separate list request' do
      post "#{path}/collection", params: { claimed: true, gift_taken: '  Voucher  ' }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(data['claimed_at']).to be_present
      expect(record.reload.gift_taken).to eq('Voucher')

      get list_path, headers: headers
      rows = data.first.key?('winners') ? data.first['winners'] : data
      expect(rows.first.slice('claimed_at', 'gift_taken', 'collection_updated_at')).to eq(
        'claimed_at' => record.claimed_at.iso8601, 'gift_taken' => 'Voucher',
        'collection_updated_at' => record.collection_updated_at.iso8601
      )
    end

    it 'updates only the supplied field and allows undo and clearing' do
      post "#{path}/collection", params: { claimed: true, gift_taken: 'Voucher' }, headers: headers, as: :json
      claimed_at = record.reload.claimed_at
      post "#{path}/collection", params: { gift_taken: '' }, headers: headers, as: :json
      expect(record.reload.claimed_at).to eq(claimed_at)
      expect(record.gift_taken).to be_nil
      post "#{path}/collection", params: { claimed: false }, headers: headers, as: :json
      expect(record.reload.claimed_at).to be_nil
      expect(record.collection_updated_at).to be_present
    end

    it 'imports untouched records once and protects subsequent edits including undo' do
      post "#{path}/collection", params: { claimed: true, gift_taken: 'Old gift', import_only: true }, headers: headers, as: :json
      expect(data['skipped']).to be(false)
      post "#{path}/collection", params: { claimed: false, gift_taken: 'New gift' }, headers: headers, as: :json
      post "#{path}/collection", params: { claimed: true, gift_taken: 'Old gift', import_only: true }, headers: headers, as: :json
      expect(data['skipped']).to be(true)
      expect(record.reload.claimed_at).to be_nil
      expect(record.gift_taken).to eq('New gift')
    end

    it 'rejects malformed collection data without modifying the winner' do
      [{ claimed: 'maybe' }, { gift_taken: ['gift'] }, { gift_taken: 'x' * 501 }, { ticket_id: ticket.id }].each do |params|
        post "#{path}/collection", params: params, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(record.reload.collection_updated_at).to be_nil
      end
    end

    it 'refuses users without session access' do
      outsider = create(:user)
      post "#{path}/collection", params: { claimed: true },
           headers: { 'Authorization' => "Bearer #{JwtService.generate_tokens(outsider)[:access_token]}" }, as: :json
      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
      expect(record.reload.claimed_at).to be_nil
    end

    it 'cannot address a winner through another session' do
      other = create(:lucky_draw_session, event: event, created_by: owner)
      post "#{path.sub("/sessions/#{session.id}/", "/sessions/#{other.id}/")}/collection",
           params: { claimed: true }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(record.reload.claimed_at).to be_nil
    end
  end

  context 'without gifts' do
    let!(:record) { session.invalid_participants.create!(ticket: ticket) }
    let(:path) { "#{base}/invalid_participants/#{record.id}" }
    let(:list_path) { "#{base}/invalid_participants" }
    include_examples 'shared collection'
  end

  context 'with gifts' do
    let(:gift) { create(:gift, lucky_draw_session: session) }
    let!(:record) { gift.gift_winners.create!(ticket: ticket, drawn_at: Time.current) }
    let(:path) { "#{base}/gifts/#{gift.id}/winners/#{record.id}" }
    let(:list_path) { "#{base}/gifts" }
    include_examples 'shared collection'
  end

  it 'supports visitor winners without ticket identity fields' do
    event.update!(use_ticket: false)
    visitor = create(:visitor, event: event)
    record = session.invalid_participants.create!(visitor: visitor)
    post "#{base}/invalid_participants/#{record.id}/collection", params: { claimed: true, gift_taken: 'Hamper' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    get "#{base}/invalid_participants", headers: headers
    expect(data.first['participant']).to include('contact' => visitor.draw_contact, 'ticket_public_id' => nil)
    expect(data.first['gift_taken']).to eq('Hamper')
  end

  context 'identity labels' do
    let(:event) { create(:event, id: 35, use_ticket: true) }
    before { ticket.update!(custom_fields_data: { ic_passport_no: '010203-12-3456' }) }

    it 'includes only the display label in the pool, with full identity on the winner' do
      get "#{base}/participants", headers: headers
      expect(data.first['contact']).to eq('ID 123456')
      expect(data.first).not_to have_key('ic_passport_no')
      record = session.invalid_participants.create!(ticket: ticket)
      get "#{base}/invalid_participants", headers: headers
      expect(data.first['participant']).to include('contact' => 'ID 123456', 'ic_passport_no' => '010203-12-3456', 'ticket_public_id' => ticket.public_id)
      expect(data.first['id']).to eq(record.id)
    end

    it 'uses the same identity fields on gift lists and newly assigned winners' do
      gift = create(:gift, lucky_draw_session: session)
      post "#{base}/gifts/#{gift.id}/winners", params: { ticket_id: ticket.id }, headers: headers
      expect(data).to include('participant_contact' => 'ID 123456', 'ic_passport_no' => '010203-12-3456', 'ticket_public_id' => ticket.public_id)
      get "#{base}/gifts", headers: headers
      expect(data.first['winners'].first).to include('participant_contact' => 'ID 123456', 'ticket_public_id' => ticket.public_id)
    end

    it 'falls back to the usual contact when no IC/passport is available' do
      ticket.update!(custom_fields_data: {})
      get "#{base}/participants", headers: headers
      expect(data.first['contact']).to eq(ticket.draw_contact)
    end

    it 'does not expose full IC/passport numbers to exhibitors' do
      exhibitor = create(:user, :exhibitor)
      create(:exhibitor, event: event, vendor: exhibitor)
      own_session = create(:lucky_draw_session, event: event, created_by: exhibitor)
      own_session.invalid_participants.create!(ticket: ticket)
      get "/v1/events/#{event.id}/lucky_draw/sessions/#{own_session.id}/invalid_participants",
          headers: { 'Authorization' => "Bearer #{JwtService.generate_tokens(exhibitor)[:access_token]}" }
      expect(response).to have_http_status(:ok)
      expect(data.first['participant']).not_to have_key('ic_passport_no')
      expect(data.first['participant']).not_to have_key('ticket_public_id')
    end
  end
end
