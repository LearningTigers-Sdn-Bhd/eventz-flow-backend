require 'rails_helper'

RSpec.describe 'V1::Roulette void an unclaimed prize', type: :request do
  let(:event) { create(:event, use_ticket: true) }
  let(:org_owner) { create(:user, :org_owner) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:session) { create(:roulette_session, event: event, user: org_owner, is_multiple: false) }
  let(:prize) { create(:roulette_prize, roulette_session: session, quantity: 1) }
  let(:ticket) { create(:ticket, :paid, event: event, ticket_type: create(:ticket_type, event: event)) }
  let!(:winner) { create(:roulette_winner, roulette_session: session, roulette_prize: prize, ticket: ticket) }
  let(:path) { "/v1/events/#{event.id}/roulette/sessions/#{session.id}/winners/#{winner.id}" }

  def json
    JSON.parse(response.body)['data']
  end

  it 'puts the prize back in stock but keeps the winner on record' do
    expect(prize.remaining_quantity).to eq(0)

    post "#{path}/void", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json['voided_at']).to be_present
    expect(prize.reload.remaining_quantity).to eq(1)
    expect(prize.has_winner?).to be(false)
    expect(RouletteWinner.exists?(winner.id)).to be(true)
  end

  it 'still stops a one-prize-per-person session from paying the same person twice' do
    post "#{path}/void", headers: headers

    again = session.roulette_winners.build(roulette_prize: prize, ticket: ticket, drawn_at: Time.current)
    expect(again).not_to be_valid
  end

  it 'lists the voided winner with its voided_at on the prize' do
    post "#{path}/void", headers: headers

    get "/v1/events/#{event.id}/roulette/sessions/#{session.id}/prizes", headers: headers
    expect(json.first['winners'].map { |w| w['voided_at'].present? }).to eq([true])
  end

  it 'is idempotent and can be undone' do
    2.times { post "#{path}/void", headers: headers }
    expect(response).to have_http_status(:ok)

    post "#{path}/unvoid", headers: headers
    expect(json['voided_at']).to be_nil
    expect(prize.reload.remaining_quantity).to eq(0)
  end

  it 'refuses a user who cannot manage the session' do
    outsider = create(:user)
    outsider_headers = { 'Authorization' => "Bearer #{JwtService.generate_tokens(outsider)[:access_token]}" }

    post "#{path}/void", headers: outsider_headers

    expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    expect(winner.reload.voided_at).to be_nil
  end
end
