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

    it "lets the host attach their own avatar" do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image data'), filename: 'me.jpg', content_type: 'image/jpeg'
      )

      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { avatar_signed_id: blob.signed_id },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['avatar_url']).to be_present
    end

    it "reports tags_editable true by default (no session assignment)" do
      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { description: "hi" },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['tags_editable']).to eq(true)
    end

    it "rejects a tag change once the host's session locks tags_editable" do
      session = BusinessMatchingSession.create!(
        event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current, tags_editable: false
      )
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)

      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { offering_tags: ["Ruby"] },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a locked-out host still edit non-tag fields" do
      session = BusinessMatchingSession.create!(
        event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current, tags_editable: false
      )
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)

      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { description: "Updated bio" },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['tags_editable']).to eq(false)
    end

    it "lets a per-host override unlock tags even when the session locks them" do
      session = BusinessMatchingSession.create!(
        event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current, tags_editable: false
      )
      BusinessHostAssignment.create!(
        user: host_user, event: event, business_matching_event_id: session.id.to_s, tags_editable_override: true
      )

      put "/v1/business_matching/events/#{event.id}/host_profile",
          params: { offering_tags: ["Ruby"] },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['offering_tags']).to eq(["Ruby"])
    end
  end

  describe "PATCH /v1/business_matching/events/:event_id/hosts/:host_user_id/profile" do
    let(:admin) { create(:user, role: :organizer) }

    before do
      create(:event_assignment, event: event, user: admin, role: :event_admin)
    end

    it "lets an event admin set another host's avatar" do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image data'), filename: 'host.jpg', content_type: 'image/jpeg'
      )

      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: { avatar_signed_id: blob.signed_id },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response['avatar_url']).to be_present
    end

    it "rejects a non-admin, non-owning user" do
      other_user = create(:user)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image data'), filename: 'host.jpg', content_type: 'image/jpeg'
      )

      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: { avatar_signed_id: blob.signed_id },
            headers: auth_headers(other_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a business matching admin set a host's avatar" do
      bm_admin = create(:user)
      create(:event_assignment, event: event, user: bm_admin, role: :business_matching_admin)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image data'), filename: 'host.jpg', content_type: 'image/jpeg'
      )

      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: { avatar_signed_id: blob.signed_id },
            headers: auth_headers(bm_admin)

      expect(response).to have_http_status(:ok)
      expect(json_response['avatar_url']).to be_present
    end

    it "lets an admin set a host's tags directly, from the curated list" do
      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: { offering_tags: ["Ruby"], interest_tags: ["React"] },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response['offering_tags']).to eq(["Ruby"])
      expect(json_response['interest_tags']).to eq(["React"])
    end

    it "rejects an admin setting tags outside the curated list" do
      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: { offering_tags: ["Made Up Tag"] },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "lets an admin set a host's description/sourcing_intent/capabilities directly" do
      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: {
              description: "We build fintech infra",
              sourcing_intent: "Looking for API partners",
              capabilities: "Payments, KYC"
            },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response['description']).to eq("We build fintech infra")
      expect(json_response['sourcing_intent']).to eq("Looking for API partners")
      expect(json_response['capabilities']).to eq("Payments, KYC")
    end

    it "lets an admin set a per-host tags_editable override for a specific session" do
      session = BusinessMatchingSession.create!(
        event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current, tags_editable: true
      )
      assignment = BusinessHostAssignment.create!(
        user: host_user, event: event, business_matching_event_id: session.id.to_s
      )

      patch "/v1/business_matching/events/#{event.id}/hosts/#{host_user.id}/profile",
            params: { tags_editable_override: false, business_matching_event_id: session.id.to_s },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(assignment.reload.tags_editable_override).to eq(false)
      expect(session.reload.tags_editable_for(host_user)).to eq(false)
    end
  end

  describe "POST /v1/business_matching/events/:event_id/hosts/create_and_assign" do
    let(:admin) { create(:user, role: :organizer) }

    before do
      create(:event_assignment, event: event, user: admin, role: :event_admin)
    end

    it "lets an admin set the new host's initial tags" do
      post "/v1/business_matching/events/#{event.id}/hosts/create_and_assign",
           params: {
             business_matching_event_id: "bm-1",
             host: { full_name: "New Host", email: "newhost@example.com", password: "password123" },
             offering_tags: ["Ruby"],
             interest_tags: ["React"]
           },
           headers: auth_headers(admin)

      expect(response).to have_http_status(:created)
      expect(json_response['offering_tags']).to eq(["Ruby"])
      expect(json_response['interest_tags']).to eq(["React"])

      new_host = User.find_by(email: "newhost@example.com")
      participant = BusinessMatchingParticipant.find_by(event: event, registerable: new_host)
      expect(participant.offering_tags).to eq(["Ruby"])
    end

    it "rejects tags outside the curated list" do
      post "/v1/business_matching/events/#{event.id}/hosts/create_and_assign",
           params: {
             business_matching_event_id: "bm-1",
             host: { full_name: "New Host", email: "newhost2@example.com", password: "password123" },
             offering_tags: ["Made Up Tag"]
           },
           headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(email: "newhost2@example.com")).to eq(false)
    end
  end

  describe "POST /v1/business_matching/events/:event_id/hosts/invite_link" do
    let(:admin) { create(:user, role: :organizer) }
    let(:session) do
      BusinessMatchingSession.create!(
        event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current
      )
    end

    before do
      create(:event_assignment, event: event, user: admin, role: :event_admin)
    end

    it "mints a token for an event admin" do
      post "/v1/business_matching/events/#{event.id}/hosts/invite_link",
           params: { business_matching_event_id: session.id.to_s },
           headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present

      access = BusinessHostInviteToken.verify(json_response['token'])
      expect(access.event_id).to eq(event.id.to_s)
      expect(access.business_matching_event_id).to eq(session.id.to_s)
    end

    it "rejects a non-admin" do
      post "/v1/business_matching/events/#{event.id}/hosts/invite_link",
           params: { business_matching_event_id: session.id.to_s },
           headers: auth_headers(host_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /v1/business_matching/host_invites/accept" do
    let(:invitee) { create(:user) }
    let(:session) do
      BusinessMatchingSession.create!(
        event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.current, end_date: Date.current
      )
    end

    it "joins the invitee as a business host using only the token, no IDs" do
      token = BusinessHostInviteToken.issue(event_id: event.id, business_matching_event_id: session.id.to_s)

      post "/v1/business_matching/host_invites/accept",
           params: { token: token },
           headers: auth_headers(invitee)

      expect(response).to have_http_status(:ok)
      expect(
        BusinessHostAssignment.exists?(
          user_id: invitee.id, event_id: event.id, business_matching_event_id: session.id.to_s
        )
      ).to eq(true)
      expect(
        EventAssignment.exists?(user_id: invitee.id, event_id: event.id, role: :business_host)
      ).to eq(true)
    end

    it "rejects a hand-typed/garbage token" do
      post "/v1/business_matching/host_invites/accept",
           params: { token: "totally-made-up-token" },
           headers: auth_headers(invitee)

      expect(response).to have_http_status(:unprocessable_content)
      expect(BusinessHostAssignment.where(user_id: invitee.id, event_id: event.id)).to be_empty
    end

    it "rejects a token that's been tampered with" do
      token = BusinessHostInviteToken.issue(event_id: event.id, business_matching_event_id: session.id.to_s)
      tampered = "#{token}x"

      post "/v1/business_matching/host_invites/accept",
           params: { token: tampered },
           headers: auth_headers(invitee)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires authentication" do
      token = BusinessHostInviteToken.issue(event_id: event.id, business_matching_event_id: session.id.to_s)

      post "/v1/business_matching/host_invites/accept", params: { token: token }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
