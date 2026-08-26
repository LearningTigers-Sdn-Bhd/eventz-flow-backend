require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorTeamMembers' do
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:vendor) { create(:exhibitor, event: event) }
  let(:kit) { create(:exhibitor_kit, event_vendor: vendor) }
  let(:path) { "/v1/public/exhibitor_kits/#{kit.public_id}/team_members" }

  describe 'GET show' do
    it 'returns kit info and team members without authentication' do
      get path

      expect(response).to have_http_status(:ok)
      body = response.parsed_body['data']
      expect(body['company_name']).to eq(kit.company_name)
      expect(body['team_members'].size).to eq(2)
    end

    it '404s for an unknown public_id' do
      get '/v1/public/exhibitor_kits/does-not-exist/team_members'

      expect(response).to have_http_status(:not_found)
    end

    it 'stays alive up to a day after the event ends' do
      event.update_columns(end_date: 12.hours.ago)

      get path

      expect(response).to have_http_status(:ok)
    end

    it 'expires more than a day after the event ends' do
      event.update_columns(end_date: 2.days.ago)

      get path

      expect(response).to have_http_status(:gone)
    end

    it 'never expires when the event has no end_date (defensive — Event validates end_date presence)' do
      event.update_columns(end_date: nil)

      get path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH update' do
    it 'adds a new team member' do
      existing = kit.exhibitor_team_members.map { |m| { id: m.id, full_name: m.full_name, email: m.email, phone: m.phone } }
      patch path, params: {
        exhibitor_team_members: existing + [{ full_name: 'New Member', email: 'new@example.com', phone: '0123456789' }]
      }

      expect(response).to have_http_status(:ok)
      expect(kit.reload.exhibitor_team_members.count).to eq(3)
    end

    it 'removes a team member via _destroy' do
      member = kit.exhibitor_team_members.first
      patch path, params: {
        exhibitor_team_members: [{ id: member.id, _destroy: true }]
      }

      expect(response).to have_http_status(:ok)
      expect(kit.reload.exhibitor_team_members.count).to eq(1)
    end

    it 'rejects changes on a cancelled kit' do
      kit.update!(booking_status: :cancelled)
      patch path, params: {
        exhibitor_team_members: [{ full_name: 'New Member', email: 'new@example.com', phone: '0123456789' }]
      }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
