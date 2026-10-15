require 'rails_helper'

RSpec.describe "V1::BusinessMatching::EventDefaults", type: :request do
  let(:event) { create(:event, use_business_matching: true) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user) }

  describe "GET /v1/business_matching/events/:event_id/defaults" do
    it "returns the event's defaults to an event admin" do
      create(:event_assignment, event: event, user: member_user, role: :event_admin)

      get "/v1/business_matching/events/#{event.id}/defaults", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['default_hours']).to eq([{ 'start_time' => '09:00', 'end_time' => '17:00' }])
      expect(json_response['hours_editable_default']).to eq(true)
      expect(json_response['default_slot_duration']).to eq(30)
      expect(json_response['public_booking_enabled']).to eq(true)
      expect(json_response['public_booking_cutoff_date']).to be_nil
      expect(json_response['public_booking_past_cutoff_warning']).to eq(false)
      expect(json_response['auto_approve_bookings']).to eq(false)
    end

    it "returns the event's defaults to a business matching admin" do
      create(:event_assignment, event: event, user: member_user, role: :business_matching_admin)

      get "/v1/business_matching/events/#{event.id}/defaults", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a plain business host" do
      create(:event_assignment, event: event, user: member_user, role: :business_host)

      get "/v1/business_matching/events/#{event.id}/defaults", headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /v1/business_matching/events/:event_id/defaults" do
    it "lets an organizer set the default date range, hours template, and editability toggle" do
      put "/v1/business_matching/events/#{event.id}/defaults",
          params: {
            default_start_date: "2026-09-03",
            default_end_date: "2026-09-03",
            default_hours: [{ start_time: "11:00", end_time: "17:00" }],
            hours_editable_default: false,
            default_slot_duration: 45
          },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['default_start_date']).to eq("2026-09-03")
      expect(json_response['hours_editable_default']).to eq(false)
      expect(json_response['default_slot_duration']).to eq(45)

      # A new session created without explicit dates/hours now follows the event's default
      post "/v1/business_matching/sessions",
           params: { event_id: event.id, session: { title: "Follows Default" } },
           headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:created)
      session = BusinessMatchingSession.find(json_response['id'])
      expect(session.start_date).to eq(Date.new(2026, 9, 3))
      blocks = session.business_matching_availabilities.pluck(:start_time, :end_time)
      expect(blocks).to eq([["11:00", "17:00"]])
    end

    it "forbids a business host" do
      host = create(:user)
      create(:event_assignment, event: event, user: host, role: :business_host)

      put "/v1/business_matching/events/#{event.id}/defaults",
          params: { hours_editable_default: false },
          headers: auth_headers(host)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets an organizer disable public booking and set a cutoff date" do
      put "/v1/business_matching/events/#{event.id}/defaults",
          params: { public_booking_enabled: false, public_booking_cutoff_date: "2026-09-01" },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['public_booking_enabled']).to eq(false)
      expect(json_response['public_booking_cutoff_date']).to eq("2026-09-01")
      expect(event.reload.business_matching_public_booking_enabled).to eq(false)
    end

    it "lets an organizer turn auto-approve on" do
      put "/v1/business_matching/events/#{event.id}/defaults",
          params: { auto_approve_bookings: true },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['auto_approve_bookings']).to eq(true)
      expect(event.reload.business_matching_auto_approve_bookings).to eq(true)
    end

    it "flags the past-cutoff warning once enabled and the date has passed" do
      put "/v1/business_matching/events/#{event.id}/defaults",
          params: { public_booking_enabled: true, public_booking_cutoff_date: "2020-01-01" },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)
      expect(json_response['public_booking_past_cutoff_warning']).to eq(true)
    end
  end
end
