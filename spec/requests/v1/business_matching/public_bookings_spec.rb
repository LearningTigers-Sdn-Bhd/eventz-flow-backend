require 'rails_helper'

RSpec.describe "V1::BusinessMatching::Bookings public_create", type: :request do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_business_matching: true) }
  let(:host_user) { create(:user) }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: "S", slot_duration: 30, start_time: "09:00", end_time: "17:00",
      start_date: Date.current, end_date: Date.current + 30
    )
  end
  let(:visitor) { create(:user) }

  before do
    create(:event_assignment, event: event, user: host_user, role: :business_host)
    BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)
  end

  def booking_params
    {
      business_matching_event_id: session.id.to_s,
      host_user_id: host_user.id,
      booking: { name: "Visitor", email: "visitor@example.com", phone: "0123456789", date: Date.current.to_s, time: "10:00 AM" }
    }
  end

  it "allows a public booking when enabled with no cutoff date" do
    post "/v1/business_matching/events/#{event.id}/bookings/public",
         params: booking_params, headers: auth_headers(visitor)

    expect(response).to have_http_status(:created)
  end

  it "emails both the visitor and the host a confirmation" do
    perform_enqueued_jobs do
      expect {
        post "/v1/business_matching/events/#{event.id}/bookings/public",
             params: booking_params, headers: auth_headers(visitor)
      }.to change { ActionMailer::Base.deliveries.size }.by(2)
    end

    recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
    expect(recipients).to contain_exactly("visitor@example.com", host_user.email)
  end

  it "allows a public booking when enabled with a future cutoff date" do
    event.update!(business_matching_public_booking_cutoff_date: Date.current + 5)

    post "/v1/business_matching/events/#{event.id}/bookings/public",
         params: booking_params, headers: auth_headers(visitor)

    expect(response).to have_http_status(:created)
  end

  it "rejects a public booking once manually disabled" do
    event.update!(business_matching_public_booking_enabled: false)

    post "/v1/business_matching/events/#{event.id}/bookings/public",
         params: booking_params, headers: auth_headers(visitor)

    expect(response).to have_http_status(:forbidden)
    expect(BusinessMatchingBooking.count).to eq(0)
  end

  it "rejects a public booking once the cutoff date has passed" do
    event.update!(business_matching_public_booking_cutoff_date: Date.current - 1)

    post "/v1/business_matching/events/#{event.id}/bookings/public",
         params: booking_params, headers: auth_headers(visitor)

    expect(response).to have_http_status(:forbidden)
    expect(BusinessMatchingBooking.count).to eq(0)
  end

  it "still lets staff create a booking directly after the cutoff date has passed" do
    event.update!(business_matching_public_booking_cutoff_date: Date.current - 1)
    admin = create(:user)
    create(:event_assignment, event: event, user: admin, role: :event_admin)

    post "/v1/business_matching/events/#{session.id}/bookings",
         params: {
           event_id: event.id,
           booking: { name: "Walk-in", email: "walkin@example.com", phone: "0123456789", date: Date.current.to_s, time: "11:00 AM" }
         },
         headers: auth_headers(admin)

    expect(response).to have_http_status(:created)
  end

  context "when auto-approve is disabled for the event" do
    before { event.update!(business_matching_auto_approve_bookings: false) }

    it "creates the booking as Pending rather than Approved" do
      post "/v1/business_matching/events/#{event.id}/bookings/public",
           params: booking_params, headers: auth_headers(visitor)

      expect(response).to have_http_status(:created)
      expect(json_response["status"]).to eq("Pending")
      expect(BusinessMatchingBooking.last.status).to eq("Pending")
    end

    it "tells the booker the request is awaiting approval instead of confirming it" do
      perform_enqueued_jobs do
        post "/v1/business_matching/events/#{event.id}/bookings/public",
             params: booking_params, headers: auth_headers(visitor)
      end

      booker_email = ActionMailer::Base.deliveries.find { |m| m.to.include?("visitor@example.com") }
      expect(booker_email.subject).to include("Awaiting Approval")
      expect(booker_email.subject).not_to include("Booking Confirmation")
    end

    it "still creates staff-made bookings as Approved" do
      admin = create(:user)
      create(:event_assignment, event: event, user: admin, role: :event_admin)

      post "/v1/business_matching/events/#{session.id}/bookings",
           params: {
             event_id: event.id,
             booking: { name: "Walk-in", email: "walkin@example.com", phone: "0123456789", date: Date.current.to_s, time: "11:00 AM" }
           },
           headers: auth_headers(admin)

      expect(response).to have_http_status(:created)
      expect(BusinessMatchingBooking.last.status).to eq("Approved")
    end
  end
end
