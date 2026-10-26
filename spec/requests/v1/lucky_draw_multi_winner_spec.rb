require 'rails_helper'

RSpec.describe 'V1::LuckyDraw multi-winner draw', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:session) { create(:lucky_draw_session, event: event, created_by: org_owner) }
  let(:base) { "/v1/events/#{event.id}/lucky_draw/sessions/#{session.id}" }
  let!(:tickets) { create_list(:ticket, 3, :paid, event: event, ticket_type: ticket_type) }

  describe 'winners_per_draw setting' do
    it 'defaults to 1 and persists through create and update' do
      post "/v1/events/#{event.id}/lucky_draw/sessions",
           params: { title: 'S', draw_styles: { style: 'wheel', theme: 'wireframe' } }, headers: headers
      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)['data']
      expect(data['winners_per_draw']).to eq(1)

      put "/v1/events/#{event.id}/lucky_draw/sessions/#{data['id']}", params: { winners_per_draw: 25 }, headers: headers
      expect(JSON.parse(response.body)['data']['winners_per_draw']).to eq(25)
    end

    it 'rejects values outside 1..200' do
      [0, 201].each do |value|
        put base, params: { winners_per_draw: value }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'POST invalid_participants/bulk (no-gift mode)' do
    it 'saves every winner and removes them from the pool' do
      winners = tickets.first(2).map { |t| { ticket_id: t.id } }
      post "#{base}/invalid_participants/bulk", params: { winners: winners }, headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data'].size).to eq(2)
      expect(session.invalid_participants.count).to eq(2)

      get "#{base}/participants", headers: headers
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] }).to eq([tickets.last.id])
    end

    it 'rolls everything back when one winner is invalid' do
      winners = [{ ticket_id: tickets.first.id }, { ticket_id: 0 }]
      post "#{base}/invalid_participants/bulk", params: { winners: winners }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(session.invalid_participants.count).to eq(0)
    end

    it 'rejects an empty list' do
      post "#{base}/invalid_participants/bulk", params: { winners: [] }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'draw rounds (no-gift mode)' do
    def rounds
      session.invalid_participants.order(:id).pluck(:round)
    end

    it 'gives every winner of one bulk draw the same round' do
      winners = tickets.first(2).map { |t| { ticket_id: t.id } }
      post "#{base}/invalid_participants/bulk", params: { winners: winners }, headers: headers

      expect(rounds).to eq([1, 1])
      expect(JSON.parse(response.body)['data'].map { |w| w['round'] }).to eq([1, 1])
    end

    it 'numbers each new draw one higher than the last' do
      post "#{base}/invalid_participants/bulk", params: { winners: [{ ticket_id: tickets[0].id }] }, headers: headers
      post "#{base}/invalid_participants", params: { ticket_id: tickets[1].id }, headers: headers
      post "#{base}/invalid_participants/bulk", params: { winners: [{ ticket_id: tickets[2].id }] }, headers: headers

      expect(rounds).to eq([1, 2, 3])
    end

    it 'starts at round 1 after winners saved before rounds existed' do
      session.invalid_participants.create!(ticket_id: tickets[0].id)
      post "#{base}/invalid_participants", params: { ticket_id: tickets[1].id }, headers: headers

      expect(rounds).to eq([nil, 1])
    end

    it 'does not use a round when the whole draw is rejected' do
      winners = [{ ticket_id: tickets.first.id }, { ticket_id: 0 }]
      post "#{base}/invalid_participants/bulk", params: { winners: winners }, headers: headers
      post "#{base}/invalid_participants", params: { ticket_id: tickets.first.id }, headers: headers

      expect(rounds).to eq([1])
    end

    it 'lists the round of each winner' do
      post "#{base}/invalid_participants", params: { ticket_id: tickets.first.id }, headers: headers
      get "#{base}/invalid_participants", headers: headers

      expect(JSON.parse(response.body)['data'].map { |w| w['round'] }).to eq([1])
    end
  end
end
