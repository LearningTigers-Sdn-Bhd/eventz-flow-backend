require 'rails_helper'

RSpec.describe "V1::BusinessMatching::Availabilities", type: :request do
  let(:event) { create(:event, use_business_matching: true) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:host_user) { create(:user) }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: "Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
      start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 1)
    )
  end

  describe "GET /v1/business_matching/sessions/:session_id/availabilities" do
    it "returns only the host's bucket, not both, when a host has their own rows" do
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)
      BusinessMatchingAvailability.create!(
        business_matching_session: session, host_user_id: nil,
        day: Date.new(2026, 9, 1), start_time: "09:00", end_time: "17:00"
      )
      BusinessMatchingAvailability.create!(
        business_matching_session: session, host_user_id: host_user.id,
        day: Date.new(2026, 9, 1), start_time: "09:00", end_time: "17:00"
      )

      get "/v1/business_matching/sessions/#{session.id}/availabilities",
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first["host_user_id"]).to eq(host_user.id.to_s)
    end

    it "returns the default bucket when no host has their own rows" do
      BusinessMatchingAvailability.create!(
        business_matching_session: session, host_user_id: nil,
        day: Date.new(2026, 9, 1), start_time: "09:00", end_time: "17:00"
      )

      get "/v1/business_matching/sessions/#{session.id}/availabilities",
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first["host_user_id"]).to be_nil
    end
  end

  describe "POST /v1/business_matching/sessions/:session_id/availabilities" do
    it "writes to the host's bucket (not the default one) when a host already has their own rows" do
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)
      BusinessMatchingAvailability.create!(
        business_matching_session: session, host_user_id: host_user.id,
        day: Date.new(2026, 9, 1), start_time: "09:00", end_time: "17:00"
      )

      post "/v1/business_matching/sessions/#{session.id}/availabilities",
           params: { availabilities: [{ day: "2026-09-01", start_time: "10:00", end_time: "16:00" }] },
           headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      rows = BusinessMatchingAvailability.where(business_matching_session_id: session.id)
      expect(rows.count).to eq(1)
      expect(rows.first.host_user_id).to eq(host_user.id)
      expect(rows.first.start_time).to eq("10:00")
    end

    it "rejects the assigned host once the session locks hours_editable" do
      session.update!(hours_editable: false)
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)

      post "/v1/business_matching/sessions/#{session.id}/availabilities",
           params: { availabilities: [{ day: "2026-09-01", start_time: "10:00", end_time: "16:00" }] },
           headers: auth_headers(host_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a per-host override unlock hours even when the session locks them" do
      session.update!(hours_editable: false)
      BusinessHostAssignment.create!(
        user: host_user, event: event, business_matching_event_id: session.id.to_s, hours_editable_override: true
      )

      post "/v1/business_matching/sessions/#{session.id}/availabilities",
           params: { availabilities: [{ day: "2026-09-01", start_time: "10:00", end_time: "16:00" }] },
           headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
    end

    it "still lets staff edit hours even when the session locks them for hosts" do
      session.update!(hours_editable: false)

      post "/v1/business_matching/sessions/#{session.id}/availabilities",
           params: { availabilities: [{ day: "2026-09-01", start_time: "10:00", end_time: "16:00" }] },
           headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
    end
  end
end
