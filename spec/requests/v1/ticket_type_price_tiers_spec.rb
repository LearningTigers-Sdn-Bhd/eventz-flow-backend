require 'rails_helper'

RSpec.describe "V1::TicketTypePriceTiers", type: :request do
  # Create test users
  let!(:event_owner) { create(:user, :organizer) }
  let!(:regular_user) { create(:user, :member) }

  # Create a test event with an owner
  let!(:event) do
    evt = create(:event)
    create(:event_assignment, role: :event_admin, event: evt, user: event_owner)
    evt
  end

  let!(:ticket_type) { create(:ticket_type, event: event) }

  # JWT tokens for authentication
  let(:owner_token) { JwtService.generate_tokens(event_owner)[:access_token] }
  let(:regular_token) { JwtService.generate_tokens(regular_user)[:access_token] }

  # Auth headers
  let(:owner_headers) { { 'Authorization' => "Bearer #{owner_token}" } }
  let(:regular_headers) { { 'Authorization' => "Bearer #{regular_token}" } }

  describe "GET /v1/ticket_types/:ticket_type_id/price_tiers" do
    let!(:tier1) do
      create(:ticket_type_price_tier,
        ticket_type: ticket_type,
        label: "Early Bird",
        starts_at: 1.day.from_now,
        ends_at: 10.days.from_now
      )
    end
    let!(:tier2) do
      create(:ticket_type_price_tier,
        ticket_type: ticket_type,
        label: "Regular",
        starts_at: 11.days.from_now,
        ends_at: 20.days.from_now
      )
    end

    it "returns all price tiers for the ticket type" do
      get "/v1/ticket_types/#{ticket_type.id}/price_tiers", headers: owner_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data'].length).to eq(2)
    end

    context "when not authorized" do
      it "returns forbidden" do
        get "/v1/ticket_types/#{ticket_type.id}/price_tiers", headers: regular_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /v1/ticket_types/:ticket_type_id/price_tiers" do
    let(:valid_params) do
      {
        label: "Early Bird",
        price: 80.00,
        starts_at: 1.day.from_now,
        ends_at: 30.days.from_now
      }
    end

    it "creates a new price tier" do
      expect {
        post "/v1/ticket_types/#{ticket_type.id}/price_tiers",
          params: valid_params,
          headers: owner_headers
      }.to change(TicketTypePriceTier, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['label']).to eq("Early Bird")
    end

    context "with overlapping dates" do
      before do
        create(:ticket_type_price_tier,
          ticket_type: ticket_type,
          starts_at: 1.day.from_now,
          ends_at: 30.days.from_now
        )
      end

      it "returns an error" do
        post "/v1/ticket_types/#{ticket_type.id}/price_tiers",
          params: valid_params,
          headers: owner_headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /v1/ticket_types/:ticket_type_id/price_tiers/:id" do
    let!(:tier) { create(:ticket_type_price_tier, ticket_type: ticket_type) }

    it "updates the price tier" do
      patch "/v1/ticket_types/#{ticket_type.id}/price_tiers/#{tier.id}",
        params: { label: "Super Early Bird" },
        headers: owner_headers

      expect(response).to have_http_status(:ok)
      expect(tier.reload.label).to eq("Super Early Bird")
    end
  end

  describe "DELETE /v1/ticket_types/:ticket_type_id/price_tiers/:id" do
    let!(:tier) { create(:ticket_type_price_tier, ticket_type: ticket_type) }

    it "deletes the price tier" do
      expect {
        delete "/v1/ticket_types/#{ticket_type.id}/price_tiers/#{tier.id}",
          headers: owner_headers
      }.to change(TicketTypePriceTier, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
