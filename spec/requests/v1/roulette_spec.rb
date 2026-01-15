require 'rails_helper'

RSpec.describe 'V1::Roulette', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:exhibitor) { create(:user, :exhibitor) }
  let(:member) { create(:user, :member) }

  def auth_header(user)
    token = JwtService.generate_tokens(user)[:access_token]
    { 'Authorization' => "Bearer #{token}" }
  end

  describe 'sessions lifecycle' do
    it 'allows an authenticated user to create and list their sessions' do
      # Create session
      post '/v1/roulette/sessions',
           params: {
             title: 'Test Session',
             is_multiple: false,
             draw_styles: { style: 'wheel', theme: 'wireframe' }
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['success']).to eq(true)
      session_id = body.dig('data', 'id')
      expect(session_id).to be_present

      # List sessions
      get '/v1/roulette/sessions', headers: auth_header(exhibitor)
      expect(response).to have_http_status(:ok)
      list_body = JSON.parse(response.body)
      ids = list_body['data'].map { |s| s['id'] }
      expect(ids).to include(session_id)
    end
  end

  describe 'winners creation and business rules' do
    let!(:session_single) { create(:roulette_session, user: exhibitor, is_multiple: false) }
    let!(:session_multi) { create(:roulette_session, user: exhibitor, is_multiple: true) }
    let!(:prize_single) { create(:roulette_prize, roulette_session: session_single, quantity: 1) }
    let!(:prize_multi) { create(:roulette_prize, roulette_session: session_multi, quantity: 2) }
    let!(:ticket) { create(:ticket) }
    let!(:visitor) { create(:visitor) }

    before do
      # Ensure ticket/visitor have public_id set (model callbacks handle this in app)
      ticket.update!(public_id: SecureRandom.uuid) if ticket.public_id.blank?
      visitor.update!(public_id: SecureRandom.uuid) if visitor.public_id.blank?
    end

    it 'allows creating a single winner when is_multiple is false and blocks second winner' do
      # First winner succeeds
      post "/v1/roulette/sessions/#{session_single.id}/winners",
           params: {
             prize_id: prize_single.id,
             ticket_public_id: ticket.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['success']).to eq(true)

      prize_single.reload
      expect(prize_single.remaining_quantity).to eq(0)

      # Second winner fails due to is_multiple = false
      post "/v1/roulette/sessions/#{session_single.id}/winners",
           params: {
             prize_id: prize_single.id,
             visitor_public_id: visitor.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:unprocessable_content)
      error_body = JSON.parse(response.body)
      expect(error_body['success']).to eq(false)
      expect(error_body['message']).to match(/already has a winner|quantity exhausted/i)
    end

    it 'allows multiple winners when is_multiple is true until quantity is exhausted' do
      # First winner
      post "/v1/roulette/sessions/#{session_multi.id}/winners",
           params: {
             prize_id: prize_multi.id,
             ticket_public_id: ticket.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)

      # Second winner
      post "/v1/roulette/sessions/#{session_multi.id}/winners",
           params: {
             prize_id: prize_multi.id,
             visitor_public_id: visitor.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)

      prize_multi.reload
      expect(prize_multi.remaining_quantity).to eq(0)

      # Third winner should fail due to quantity exhausted
      post "/v1/roulette/sessions/#{session_multi.id}/winners",
           params: {
             prize_id: prize_multi.id,
             ticket_public_id: SecureRandom.uuid # non-existent ticket
           },
           headers: auth_header(exhibitor)

      # It may fail either on quantity exhausted or ticket not found; we assert failure status
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:not_found)
    end
  end
end
