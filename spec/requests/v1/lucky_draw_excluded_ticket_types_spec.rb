require 'rails_helper'

RSpec.describe 'V1::LuckyDraw excluded ticket types', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_ticket: true) }
  let(:general) { create(:ticket_type, event: event) }
  let(:vip) { create(:ticket_type, event: event) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:base_url) { "/v1/events/#{event.id}/lucky_draw/sessions" }

  let!(:general_ticket) { create(:ticket, event: event, ticket_type: general, attendee_name: 'General Guest') }
  let!(:vip_ticket) { create(:ticket, event: event, ticket_type: vip, attendee_name: 'Vip Guest') }

  def pool_names(session)
    get "#{base_url}/#{session.id}/participants", headers: headers
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['data'].map { |p| p['name'] }
  end

  [false, true].each do |use_gifts|
    it "drops excluded ticket types from the pool (use_gifts: #{use_gifts})" do
      session = create(:lucky_draw_session, event: event, created_by: org_owner, use_gifts: use_gifts,
                                            excluded_ticket_type_ids: [vip.id])
      expect(pool_names(session)).to contain_exactly('General Guest')
    end
  end

  it 'also applies on top of the scanned-only pool' do
    general_ticket.update!(checked_in: true)
    vip_ticket.update!(checked_in: true)
    session = create(:lucky_draw_session, event: event, created_by: org_owner, scanned_only: true,
                                          excluded_ticket_type_ids: [general.id])
    expect(pool_names(session)).to contain_exactly('Vip Guest')
  end

  it 'keeps everyone when nothing is excluded' do
    session = create(:lucky_draw_session, event: event, created_by: org_owner)
    expect(pool_names(session)).to contain_exactly('General Guest', 'Vip Guest')
  end

  it 'saves and clears the list through create and update' do
    post base_url, params: { title: 'S', draw_styles: { style: 'wheel', theme: 'wireframe' },
                             excluded_ticket_type_ids: [vip.id.to_s] }, headers: headers
    expect(response).to have_http_status(:created)
    data = JSON.parse(response.body)['data']
    expect(data['excluded_ticket_type_ids']).to eq([vip.id])

    put "#{base_url}/#{data['id']}", params: { excluded_ticket_type_ids: [''] }, headers: headers
    expect(JSON.parse(response.body)['data']['excluded_ticket_type_ids']).to eq([])
  end

  describe 'saving a winner' do
    let(:session) do
      create(:lucky_draw_session, event: event, created_by: org_owner, excluded_ticket_type_ids: [vip.id])
    end

    it 'rejects an excluded ticket as a no-gift winner' do
      post "#{base_url}/#{session.id}/invalid_participants", params: { ticket_id: vip_ticket.id }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(session.invalid_participants.count).to eq(0)
    end

    it 'rejects an excluded ticket as a gift winner' do
      gift = create(:gift, lucky_draw_session: session)
      post "#{base_url}/#{session.id}/gifts/#{gift.id}/winners", params: { ticket_id: vip_ticket.id }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'accepts an allowed ticket' do
      post "#{base_url}/#{session.id}/invalid_participants", params: { ticket_id: general_ticket.id }, headers: headers
      expect(response).to have_http_status(:created)
    end
  end
end
