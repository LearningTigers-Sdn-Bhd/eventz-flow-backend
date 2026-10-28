require 'rails_helper'

RSpec.describe 'V1::LuckyDraw void a no-show winner', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:base) { "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}" }
  let!(:tickets) { create_list(:ticket, 3, :paid, event: event, ticket_type: ticket_type) }

  def json
    JSON.parse(response.body)['data']
  end

  def pool_ids
    get "#{base}/participants", headers: headers
    json.map { |p| p['id'] }
  end

  context 'with gifts on' do
    let(:session) { create(:lucky_draw_session, event: event, created_by: org_owner, use_gifts: true) }
    let!(:gift) { session.gifts.create!(name: 'Phone', order: 1, winner_counts: 1) }
    let!(:winner) { gift.gift_winners.create!(ticket: tickets.first, drawn_at: Time.current) }
    let(:winner_path) { "#{base}/gifts/#{gift.id}/winners/#{winner.id}" }

    it 'reopens the gift slot but keeps the no-show out of the pool' do
      expect(gift.reload.needs_more_winners?).to be(false)

      post "#{winner_path}/void", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['voided_at']).to be_present
      expect(gift.reload.needs_more_winners?).to be(true)
      expect(pool_ids).to match_array(tickets.last(2).map(&:id))
    end

    it 'keeps the voided winner in the gift history' do
      post "#{winner_path}/void", headers: headers

      get "#{base}/gifts/#{gift.id}", headers: headers
      expect(json['winners'].map { |w| w['voided_at'].present? }).to eq([true])
    end

    it 'is idempotent and can be undone' do
      2.times { post "#{winner_path}/void", headers: headers }
      expect(response).to have_http_status(:ok)

      post "#{winner_path}/unvoid", headers: headers
      expect(json['voided_at']).to be_nil
      expect(gift.reload.needs_more_winners?).to be(false)
    end
  end

  context 'with gifts off' do
    let(:session) { create(:lucky_draw_session, event: event, created_by: org_owner, use_gifts: false) }
    let!(:record) { session.invalid_participants.create!(ticket: tickets.first, round: 1) }

    it 'voids the winner and keeps them out of the pool' do
      post "#{base}/invalid_participants/#{record.id}/void", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['voided_at']).to be_present
      expect(pool_ids).to match_array(tickets.last(2).map(&:id))
    end

    it 'can be undone' do
      post "#{base}/invalid_participants/#{record.id}/void", headers: headers
      post "#{base}/invalid_participants/#{record.id}/unvoid", headers: headers

      expect(json['voided_at']).to be_nil
    end
  end

  it 'refuses a user who cannot manage the session' do
    session = create(:lucky_draw_session, event: event, created_by: org_owner, use_gifts: false)
    record = session.invalid_participants.create!(ticket: tickets.first, round: 1)
    outsider = create(:user)
    outsider_headers = { 'Authorization' => "Bearer #{JwtService.generate_tokens(outsider)[:access_token]}" }

    post "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}/invalid_participants/#{record.id}/void",
         headers: outsider_headers

    expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    expect(record.reload.voided_at).to be_nil
  end
end
