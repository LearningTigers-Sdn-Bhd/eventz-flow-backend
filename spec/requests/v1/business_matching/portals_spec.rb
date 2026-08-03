require 'rails_helper'

RSpec.describe "V1::BusinessMatching::Portals", type: :request do
  let(:event) { create(:event, use_business_matching: true, start_date: 1.day.from_now, end_date: 2.days.from_now) }
  let(:visitor1) { create(:visitor, event: event, email: 'v1@test.com') }
  let(:visitor2) { create(:visitor, event: event, email: 'v2@test.com') }

  let(:p1) { BusinessMatchingParticipant.find_by(registerable: visitor1) }
  let(:p2) { BusinessMatchingParticipant.find_by(registerable: visitor2) }

  before do
    # Ensure they exist (created by Visitor after_commit callbacks)
    expect(p1).to be_present
    expect(p2).to be_present
  end

  describe "GET /v1/business_matching/portal" do
    it "requires a valid magic token" do
      get "/v1/business_matching/portal", params: { token: 'invalid_token' }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the participant profile and schedule" do
      get "/v1/business_matching/portal", params: { token: p1.magic_token }
      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      expect(json['participant']['id']).to eq(p1.id.to_s)
      expect(json['offering_tags']).to eq([])
      expect(json['bookings']).to eq([])
    end
  end

  describe "PUT /v1/business_matching/portal" do
    it "updates the participant tags" do
      put "/v1/business_matching/portal", params: {
        token: p1.magic_token,
        offering_tags: ["Ruby", "Rails"],
        interest_tags: ["React", "NextJS"]
      }
      expect(response).to have_http_status(:ok)

      p1.reload
      expect(p1.offering_tags).to eq(["Ruby", "Rails"])
      expect(p1.interest_tags).to eq(["React", "NextJS"])
    end
  end

  describe "GET /v1/business_matching/portal/matches" do
    before do
      # Set up tags to test similarity score calculation
      p1.update!(profile_data: { offering_tags: ["Ruby", "Rails"], interest_tags: ["React"] })
      p2.update!(profile_data: { offering_tags: ["React"], interest_tags: ["Ruby"] })
    end

    it "returns list of matches ranked by Jaccard similarity" do
      get "/v1/business_matching/portal/matches", params: { token: p1.magic_token }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first['participant']['id']).to eq(p2.id.to_s)
      # Intersection = (Ruby & Ruby) + (React & React) = 2
      # Union = [Ruby, Rails, React] = 3
      # Score = 2/3 = 66.7%
      expect(json.first['match_score']).to eq(66.7)
    end
  end

  describe "POST /v1/business_matching/portal/bookings" do
    let!(:session) do
      BusinessMatchingSession.create!(
        event: event,
        title: "Speed Match",
        slot_duration: 30,
        start_time: "09:00",
        end_time: "17:00"
      )
    end

    it "requests a 1-on-1 booking" do
      post "/v1/business_matching/portal/bookings", params: {
        token: p1.magic_token,
        receiver_participant_id: p2.id,
        date: event.start_date.to_date.to_s,
        time: "10:00 AM"
      }
      expect(response).to have_http_status(:created)

      booking = BusinessMatchingBooking.first
      expect(booking.requester_participant_id).to eq(p1.id)
      expect(booking.receiver_participant_id).to eq(p2.id)
      expect(booking.status).to eq("Approved")
    end
  end

  describe "PUT /v1/business_matching/portal/bookings/:id/respond" do
    let!(:session) do
      BusinessMatchingSession.create!(
        event: event,
        title: "Speed Match",
        slot_duration: 30,
        start_time: "09:00",
        end_time: "17:00"
      )
    end

    let!(:booking) do
      BusinessMatchingBooking.create!(
        business_matching_session: session,
        requester_participant: p1,
        receiver_participant: p2,
        name: "Visitor 1",
        email: "v1@test.com",
        phone: "123",
        booking_date: event.start_date.to_date,
        booking_time: "11:00 AM",
        status: "Pending"
      )
    end

    it "allows the receiver to accept the meeting request" do
      put "/v1/business_matching/portal/bookings/#{booking.id}/respond", params: {
        token: p2.magic_token,
        response: "accept"
      }
      expect(response).to have_http_status(:ok)

      booking.reload
      expect(booking.status).to eq("Approved")
    end

    it "prevents unauthorized users from responding" do
      put "/v1/business_matching/portal/bookings/#{booking.id}/respond", params: {
        token: p1.magic_token,
        response: "accept"
      }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
