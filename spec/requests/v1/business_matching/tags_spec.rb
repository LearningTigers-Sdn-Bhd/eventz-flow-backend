require 'rails_helper'

RSpec.describe "V1::BusinessMatching::Tags", type: :request do
  let(:event) { create(:event, use_business_matching: true) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user) }

  describe "GET /v1/business_matching/events/:event_id/tags" do
    it "returns the event's tag lists to event staff" do
      create(:event_assignment, event: event, user: member_user, role: :event_admin)

      get "/v1/business_matching/events/#{event.id}/tags", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['offering_tags']).to eq([])
      expect(json_response['interest_tags']).to eq([])
    end

    it "forbids users with no relationship to the event" do
      get "/v1/business_matching/events/#{event.id}/tags", headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /v1/business_matching/events/:event_id/tags" do
    it "allows an organizer to set the tag lists" do
      put "/v1/business_matching/events/#{event.id}/tags",
          params: { offering_tags: ["Ruby", "Ruby", " Rails "], interest_tags: ["React"] },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['offering_tags']).to eq(["Ruby", "Rails"])
      expect(json_response['interest_tags']).to eq(["React"])

      event.reload
      expect(event.business_matching_offering_tags).to eq(["Ruby", "Rails"])
    end

    it "allows an event_admin to set the tag lists" do
      create(:event_assignment, event: event, user: member_user, role: :event_admin)

      put "/v1/business_matching/events/#{event.id}/tags",
          params: { offering_tags: ["Ruby"] },
          headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a plain member (not organizer/event_admin) from setting the tag lists" do
      put "/v1/business_matching/events/#{event.id}/tags",
          params: { offering_tags: ["Ruby"] },
          headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids a business host from setting the tag lists" do
      host_user = create(:user)
      create(:event_assignment, event: event, user: host_user, role: :business_host)

      put "/v1/business_matching/events/#{event.id}/tags",
          params: { offering_tags: ["Ruby"] },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "propagates a tag rename to every participant in the event who had selected it" do
      visitor = create(:visitor, event: event)
      participant = BusinessMatchingParticipant.find_or_create_by!(event: event, registerable: visitor)
      participant.offering_tags = ["Ruby"]
      participant.save!

      put "/v1/business_matching/events/#{event.id}/tags",
          params: {
            offering_tags: ["Ruby on Rails"],
            renamed_offering_tags: [{ from: "Ruby", to: "Ruby on Rails" }]
          },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)

      participant.reload
      expect(participant.offering_tags).to eq(["Ruby on Rails"])
    end
  end
end
