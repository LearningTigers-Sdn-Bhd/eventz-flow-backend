require 'rails_helper'

RSpec.describe "V1::BusinessMatching::Sessions", type: :request do
  let(:event) do
    create(:event, use_business_matching: true, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 3))
  end
  let(:organizer_user) { create(:user, :organizer) }

  describe "POST /v1/business_matching/sessions" do
    it "defaults the session's date range to the event's dates when not specified" do
      post "/v1/business_matching/sessions",
           params: { event_id: event.id, session: { title: "Default Range Session", slot_duration: 30, start_time: "09:00", end_time: "17:00" } },
           headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:created)

      session = BusinessMatchingSession.find(json_response['id'])
      expect(session.start_date).to eq(Date.new(2026, 9, 1))
      expect(session.end_date).to eq(Date.new(2026, 9, 3))
      expect(session.business_matching_availabilities.count).to eq(3)
    end

    it "allows a session date range entirely outside the event's period" do
      post "/v1/business_matching/sessions",
           params: {
             event_id: event.id,
             session: {
               title: "Pre-Event Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
               start_date: "2026-08-20", end_date: "2026-08-21"
             }
           },
           headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:created)

      session = BusinessMatchingSession.find(json_response['id'])
      expect(session.start_date).to eq(Date.new(2026, 8, 20))
      expect(session.end_date).to eq(Date.new(2026, 8, 21))
      expect(session.business_matching_availabilities.pluck(:day)).to contain_exactly(
        Date.new(2026, 8, 20), Date.new(2026, 8, 21)
      )
    end

    it "rejects an end_date before the start_date" do
      post "/v1/business_matching/sessions",
           params: {
             event_id: event.id,
             session: {
               title: "Invalid Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
               start_date: "2026-09-05", end_date: "2026-09-01"
             }
           },
           headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors'].join).to include("on or after the start date")
    end
  end

  describe "PUT /v1/business_matching/sessions/:id" do
    it "extends availability days when the date range is widened, without touching existing bookings" do
      session = BusinessMatchingSession.create!(
        event: event, title: "Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 1)
      )
      BusinessMatchingAvailability.create!(
        business_matching_session: session, day: Date.new(2026, 9, 1), start_time: "09:00", end_time: "17:00"
      )
      expect(session.business_matching_availabilities.count).to eq(1)

      put "/v1/business_matching/sessions/#{session.id}",
          params: { session: { start_date: "2026-09-01", end_date: "2026-09-03" } },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      session.reload
      expect(session.business_matching_availabilities.pluck(:day)).to contain_exactly(
        Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3)
      )
    end

    it "extends a host's own availability bucket too, not just the default one" do
      host_user = create(:user)
      session = BusinessMatchingSession.create!(
        event: event, title: "Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 1)
      )
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)
      # Mirrors what the seeder / a host with custom hours produces: rows
      # scoped to a specific host_user_id, not the shared nil bucket.
      BusinessMatchingAvailability.create!(
        business_matching_session: session, host_user_id: host_user.id,
        day: Date.new(2026, 9, 1), start_time: "09:00", end_time: "17:00"
      )

      put "/v1/business_matching/sessions/#{session.id}",
          params: { session: { start_date: "2026-09-01", end_date: "2026-09-03" } },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      host_days = BusinessMatchingAvailability.where(
        business_matching_session_id: session.id, host_user_id: host_user.id
      ).pluck(:day)
      expect(host_days).to contain_exactly(
        Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3)
      )
    end

    it "lets the assigned host edit their own session's details" do
      host_user = create(:user, :exhibitor)
      session = BusinessMatchingSession.create!(
        event: event, title: "Old Title", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 1)
      )
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)

      put "/v1/business_matching/sessions/#{session.id}",
          params: { session: { title: "New Title", location: "Booth 5" } },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      session.reload
      expect(session.title).to eq("New Title")
      expect(session.location).to eq("Booth 5")
    end

    it "silently ignores a host's attempt to move the session's date range" do
      host_user = create(:user, :exhibitor)
      session = BusinessMatchingSession.create!(
        event: event, title: "Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 1)
      )
      BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)

      put "/v1/business_matching/sessions/#{session.id}",
          params: { session: { start_date: "2026-08-01", end_date: "2026-08-05" } },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:ok)
      session.reload
      expect(session.start_date).to eq(Date.new(2026, 9, 1))
      expect(session.end_date).to eq(Date.new(2026, 9, 1))
    end

    it "rejects a host editing a session that isn't their own" do
      host_user = create(:user, :exhibitor)
      other_host = create(:user, :exhibitor)
      session = BusinessMatchingSession.create!(
        event: event, title: "Session", slot_duration: 30, start_time: "09:00", end_time: "17:00",
        start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 1)
      )
      BusinessHostAssignment.create!(user: other_host, event: event, business_matching_event_id: session.id.to_s)

      put "/v1/business_matching/sessions/#{session.id}",
          params: { session: { title: "Hijacked Title" } },
          headers: auth_headers(host_user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
