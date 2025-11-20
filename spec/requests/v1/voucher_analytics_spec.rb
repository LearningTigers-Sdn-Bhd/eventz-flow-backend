require 'rails_helper'

RSpec.describe "V1::VoucherAnalytics", type: :request do
  describe "GET /v1/events/:event_id/voucher_analytics" do
    let(:event) { create(:event) }
    let(:user) { create(:organizer_user) }
    let(:token) { JwtService.generate_tokens(user)[:access_token] }

    it "returns http success" do
      get "/v1/events/#{event.id}/voucher_analytics", headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
    end

    it "returns the correct analytics data" do
      # Create some test data
      vouchers = create_list(:voucher, 5, event: event, vendor: user)
      vouchers.each do |voucher|
        create_list(:voucher_redemption_log, 3, voucher: voucher, redemption_timestamp: Time.current, redeemer: user)
      end

      get "/v1/events/#{event.id}/voucher_analytics", headers: { 'Authorization' => "Bearer #{token}" }
      json = JSON.parse(response.body)

      expect(json["total_vouchers_issued"]).to eq(5)
      expect(json["total_redemptions"]).to eq(15)
    end
  end
end
