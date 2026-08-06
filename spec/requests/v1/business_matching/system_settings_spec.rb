require 'rails_helper'

RSpec.describe "V1::BusinessMatching::SystemSettings", type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }

  describe "GET /v1/business_matching/system_settings" do
    it "returns the platform defaults to an org owner" do
      get "/v1/business_matching/system_settings", headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(json_response['default_hours']).to eq([{ 'start_time' => '09:00', 'end_time' => '17:00' }])
      expect(json_response['hours_editable_default']).to eq(true)
    end

    it "forbids a non-org-owner" do
      get "/v1/business_matching/system_settings", headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /v1/business_matching/system_settings" do
    it "lets an org owner set the default hours template and toggle" do
      put "/v1/business_matching/system_settings",
          params: {
            default_hours: [{ start_time: "08:00", end_time: "12:00" }, { start_time: "13:00", end_time: "18:00" }],
            hours_editable_default: false
          },
          headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(json_response['hours_editable_default']).to eq(false)
      expect(json_response['default_hours'].size).to eq(2)

      new_session = BusinessMatchingSession.create!(
        event: create(:event), title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current
      )
      expect(new_session.hours_editable_for(create(:user))).to eq(false)
    end

    it "forbids a non-org-owner" do
      put "/v1/business_matching/system_settings",
          params: { hours_editable_default: false },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
