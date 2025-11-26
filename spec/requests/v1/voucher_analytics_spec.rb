require 'rails_helper'

RSpec.describe "V1::VoucherAnalytics", type: :request do
  let(:event) { create(:event) }
  let(:user) { create(:organizer_user) }
  let(:vendor) { create(:user, role: :vendor) }
  let(:token) { JwtService.generate_tokens(user)[:access_token] }
  let!(:voucher1) { create(:voucher, event: event, vendor: user, total_redemption_available: 10) }
  let!(:voucher2) { create(:voucher, event: event, vendor: vendor, total_redemption_available: 10) }
  let!(:log1) { create(:voucher_redemption_log, voucher: voucher1, redemption_timestamp: Time.current, redeemer: user) }
  let!(:log2) { create(:voucher_redemption_log, voucher: voucher2, redemption_timestamp: Time.current, redeemer: user) }

  describe "GET /v1/events/:event_id/voucher_analytics" do
    it "returns http success" do
      get "/v1/events/#{event.id}/voucher_analytics", headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
    end

    it "returns the correct analytics data" do
      get "/v1/events/#{event.id}/voucher_analytics", headers: { 'Authorization' => "Bearer #{token}" }
      json = JSON.parse(response.body)

      expect(json["total_vouchers_issued"]).to eq(20)
      expect(json["total_redemptions"]).to eq(2)
      expect(json["event_redemption_rate"]).to eq(10.0)
      expect(json).to have_key("daily_redemption_trend")
      expect(json).to have_key("top_scanned_vouchers")
      expect(json).to have_key("latest_redemption_transactions")
    end

    context "with vendor_id filter" do
      it "returns analytics for specific vendor" do
        get "/v1/events/#{event.id}/voucher_analytics", params: { vendor_id: vendor.id }, headers: { 'Authorization' => "Bearer #{token}" }
        json = JSON.parse(response.body)

        expect(json["total_vouchers_issued"]).to eq(10)
        expect(json["total_redemptions"]).to eq(1)
      end
    end
  end

  describe "GET /v1/events/:event_id/voucher_analytics/redemption_logs" do
    it "returns http success" do
      get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:success)
    end

    it "returns list of redemption logs" do
      get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", headers: { 'Authorization' => "Bearer #{token}" }
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json.first).to have_key("voucher_title")
      expect(json.first).to have_key("redeemer_name")
    end

    context "with filters" do
      it "filters by vendor_id" do
        get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", params: { vendor_id: vendor.id }, headers: { 'Authorization' => "Bearer #{token}" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["voucher_code"]).to eq(voucher2.voucher_code)
      end

      it "filters by voucher_id" do
        get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", params: { voucher_id: voucher1.id }, headers: { 'Authorization' => "Bearer #{token}" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["voucher_code"]).to eq(voucher1.voucher_code)
      end
    end

    context "role-based access control" do
      context "when user is a vendor" do
        let(:vendor_token) { JwtService.generate_tokens(vendor)[:access_token] }

        it "returns only their own redemption logs" do
          get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", headers: { 'Authorization' => "Bearer #{vendor_token}" }
          json = JSON.parse(response.body)
          expect(json.length).to eq(1)
          expect(json.first["voucher_code"]).to eq(voucher2.voucher_code)
        end

        it "ignores vendor_id filter param" do
          get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", params: { vendor_id: user.id }, headers: { 'Authorization' => "Bearer #{vendor_token}" }
          json = JSON.parse(response.body)
          expect(json.length).to eq(1)
          expect(json.first["voucher_code"]).to eq(voucher2.voucher_code)
        end
      end

      context "when user is org_owner" do
        let(:org_owner) { create(:org_owner) }
        let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }

        it "returns all redemption logs" do
          get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", headers: { 'Authorization' => "Bearer #{org_owner_token}" }
          json = JSON.parse(response.body)
          expect(json.length).to eq(2)
        end
      end

      context "when user is unauthorized member" do
        let(:member) { create(:member_user) }
        let(:member_token) { JwtService.generate_tokens(member)[:access_token] }

        it "returns forbidden status" do
          get "/v1/events/#{event.id}/voucher_analytics/redemption_logs", headers: { 'Authorization' => "Bearer #{member_token}" }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
