require 'rails_helper'

RSpec.describe "V1::BusinessMatching::Hosts", type: :request do
  let(:event) do
    create(:event, use_business_matching: true,
                    business_matching_offering_tags: ["Ruby", "Rails"],
                    business_matching_interest_tags: ["React", "NextJS"])
  end
  let(:host_user) { create(:user) }

  before do
    create(:event_assignment, event: event, user: host_user, role: :business_host)
  end

  describe "PUT /v1/business_matching/events/:event_id/host_profile" do
    it "allows the host to select tags from the event's admin-approved list" do
      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { offering_tags: ["Ruby"], interest_tags: ["React"] },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['offering_tags']).to eq(["Ruby"])
      expect(json_response['interest_tags']).to eq(["React"])
    end

    it "rejects tags outside the event's admin-approved list" do
      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { offering_tags: ["Ruby", "Made Up Tag"] },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['errors'].join).to include("Made Up Tag")
    end
  end
end
