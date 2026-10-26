require 'rails_helper'

RSpec.describe 'V1::LuckyDraw gift pick, draw last and round sweep', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:session) { create(:lucky_draw_session, event: event, created_by: org_owner, use_gifts: true) }
  let(:base) { "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}" }
  let!(:tickets) { create_list(:ticket, 4, :paid, event: event, ticket_type: ticket_type) }
  let!(:phone) { session.gifts.create!(name: 'Phone', order: 1, winner_counts: 2) }
  let!(:voucher) { session.gifts.create!(name: 'Voucher', order: 2, winner_counts: 2) }

  def json
    JSON.parse(response.body)['data']
  end

  def sweep(*pairs)
    winners = pairs.map { |gift, ticket| { gift_id: gift.id, ticket_id: ticket.id } }
    post "#{base}/gift_winners/sweep", params: { winners: winners }, headers: headers
  end

  describe 'session options' do
    it 'defaults to in_order without a sweep and persists changes' do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: 'S', draw_styles: { style: 'wheel', theme: 'wireframe' } }, headers: headers
      expect(json).to include('gift_pick' => 'in_order', 'round_sweep' => false)

      put "/v1/events/#{event.id}/lucky_draw/sessions/#{json['id']}",
          params: { gift_pick: 'random', round_sweep: true }, headers: headers
      expect(json).to include('gift_pick' => 'random', 'round_sweep' => true)
    end

    it 'rejects an unknown gift_pick' do
      put base, params: { gift_pick: 'alphabetical' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'gift draw_last flag' do
    it 'is false by default and can be turned on' do
      post "#{base}/gifts", params: { name: 'Grand Prize' }, headers: headers
      expect(json['draw_last']).to be(false)

      put "#{base}/gifts/#{json['id']}", params: { draw_last: true }, headers: headers
      expect(json['draw_last']).to be(true)
    end
  end

  describe 'POST gift_winners/sweep' do
    it 'saves one winner per gift under one shared round' do
      sweep([phone, tickets[0]], [voucher, tickets[1]])

      expect(response).to have_http_status(:created)
      expect(json.map { |w| w['round'] }).to eq([1, 1])
      expect(phone.gift_winners.pluck(:ticket_id)).to eq([tickets[0].id])
      expect(voucher.gift_winners.pluck(:ticket_id)).to eq([tickets[1].id])
    end

    it 'numbers each sweep one higher than the last' do
      sweep([phone, tickets[0]], [voucher, tickets[1]])
      sweep([phone, tickets[2]], [voucher, tickets[3]])

      expect(GiftWinner.order(:id).pluck(:round)).to eq([1, 1, 2, 2])
    end

    it 'continues after winners drawn gift by gift, which have no round' do
      post "#{base}/gifts/#{phone.id}/winners", params: { ticket_id: tickets[0].id }, headers: headers
      sweep([voucher, tickets[1]])

      expect(GiftWinner.order(:id).pluck(:round)).to eq([nil, 1])
    end

    it 'rolls everything back when one winner is invalid' do
      post "#{base}/gift_winners/sweep",
           params: { winners: [{ gift_id: phone.id, ticket_id: tickets[0].id },
                               { gift_id: voucher.id, ticket_id: 0 }] },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(GiftWinner.count).to eq(0)

      sweep([phone, tickets[0]])
      expect(json.first['round']).to eq(1)
    end

    it 'rejects a gift from another session' do
      other = create(:lucky_draw_session, event: event, created_by: org_owner, use_gifts: true)
      stranger = other.gifts.create!(name: 'Other', order: 1, winner_counts: 1)

      sweep([stranger, tickets[0]])

      expect(response).to have_http_status(:unprocessable_content)
      expect(GiftWinner.count).to eq(0)
    end

    it 'rejects an empty list' do
      post "#{base}/gift_winners/sweep", params: { winners: [] }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lists the round of each winner on the gifts index' do
      sweep([phone, tickets[0]])
      get "#{base}/gifts", headers: headers

      winner = json.find { |gift| gift['id'] == phone.id }['winners'].first
      expect(winner['round']).to eq(1)
    end
  end

  describe 'POST gifts/:id/winners/bulk' do
    it 'still saves several winners for one gift with no round' do
      winners = tickets.first(2).map { |t| { ticket_id: t.id } }
      post "#{base}/gifts/#{phone.id}/winners/bulk", params: { winners: winners }, headers: headers

      expect(response).to have_http_status(:created)
      expect(phone.gift_winners.pluck(:round)).to eq([nil, nil])
    end

    it 'rolls everything back when one winner is invalid' do
      winners = [{ ticket_id: tickets.first.id }, { ticket_id: 0 }]
      post "#{base}/gifts/#{phone.id}/winners/bulk", params: { winners: winners }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(phone.gift_winners.count).to eq(0)
    end
  end
end
