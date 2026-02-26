require "rails_helper"

RSpec.describe "V1::ExhibitorZoneQuotas", type: :request do
  let(:event) { create(:event) }
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let!(:zone_quota) { create(:exhibitor_zone_quota, event: event, zone: "zone_d", quota: 103) }

  describe "GET /v1/events/:event_id/exhibitor_zone_quotas" do
    it "returns zone quotas for org owner" do
      get "/v1/events/#{event.id}/exhibitor_zone_quotas", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["zone"]).to eq("zone_d")
      expect(json.first["quota"]).to eq(103)
    end

    it "returns empty collection for member" do
      get "/v1/events/#{event.id}/exhibitor_zone_quotas", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe "POST /v1/events/:event_id/exhibitor_zone_quotas" do
    it "creates zone quota for org owner" do
      expect {
        post "/v1/events/#{event.id}/exhibitor_zone_quotas",
             params: { exhibitor_zone_quota: { zone: "zone_a", quota: 50 } },
             headers: auth_headers(admin_user)
      }.to change(ExhibitorZoneQuota, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["zone"]).to eq("zone_a")
      expect(json["quota"]).to eq(50)
    end
  end

  describe "PATCH /v1/exhibitor_zone_quotas/:id" do
    it "updates zone quota for org owner" do
      patch "/v1/exhibitor_zone_quotas/#{zone_quota.id}",
            params: { exhibitor_zone_quota: { quota: 120 } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(zone_quota.reload.quota).to eq(120)
    end
  end

  describe "DELETE /v1/exhibitor_zone_quotas/:id" do
    it "deletes zone quota for org owner" do
      expect {
        delete "/v1/exhibitor_zone_quotas/#{zone_quota.id}", headers: auth_headers(admin_user)
      }.to change(ExhibitorZoneQuota, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
