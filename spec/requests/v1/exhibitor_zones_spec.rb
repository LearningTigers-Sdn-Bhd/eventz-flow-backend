require 'rails_helper'

RSpec.describe 'V1::ExhibitorZones', type: :request do
  let(:event) { create(:event) }
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let!(:zone) { create(:exhibitor_zone, event: event, zone: 'zone_d', quota: 103) }

  describe 'GET /v1/events/:event_id/exhibitor_zones' do
    it 'returns zones for org owner' do
      get "/v1/events/#{event.id}/exhibitor_zones", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first['zone']).to eq('zone_d')
      expect(json.first['quota']).to eq(103)
    end

    it 'returns empty collection for member' do
      get "/v1/events/#{event.id}/exhibitor_zones", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_zones' do
    it 'creates zone for org owner' do
      expect do
        post "/v1/events/#{event.id}/exhibitor_zones",
             params: { exhibitor_zone: { zone: 'zone_a', quota: 50 } },
             headers: auth_headers(admin_user)
      end.to change(ExhibitorZone, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['zone']).to eq('zone_a')
      expect(json['quota']).to eq(50)
    end
  end

  describe 'PATCH /v1/exhibitor_zones/:id' do
    it 'updates zone for org owner' do
      patch "/v1/exhibitor_zones/#{zone.id}",
            params: { exhibitor_zone: { quota: 120 } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(zone.reload.quota).to eq(120)
    end
  end

  describe 'DELETE /v1/exhibitor_zones/:id' do
    it 'deletes zone for org owner' do
      expect do
        delete "/v1/exhibitor_zones/#{zone.id}", headers: auth_headers(admin_user)
      end.to change(ExhibitorZone, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
