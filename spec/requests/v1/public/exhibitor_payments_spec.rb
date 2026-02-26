require "rails_helper"

RSpec.describe "V1::Public::ExhibitorPayments", type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: "vendor@example.com") }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event, booth_type: "shell_scheme", label: "Malaysian", price: 1500.00) }
  let(:exhibitor_kit) do
    exhibitor.exhibitor_kit.tap do |kit|
      kit.update!(
        exhibitor_booth_price: booth_price,
        amount_paid: 1500.00,
        payment_status: :unpaid,
      )
    end
  end

  describe "POST /v1/public/events/:event_slug/exhibitor_payments/create_order" do
    it "creates a razorpay order for unpaid exhibitor kit" do
      allow(Payments::RazorpayGateway).to receive(:create_order).and_return(
        {
          "id" => "order_exhibitor_123",
          "amount" => 150_000,
          "currency" => "MYR",
        },
      )
      allow(Payments::RazorpayGateway).to receive(:key_id).and_return("rzp_test_key")

      post "/v1/public/events/#{event.slug}/exhibitor_payments/create_order", params: { exhibitor_kit_id: exhibitor_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be(true)
      expect(json["data"]["order_id"]).to eq("order_exhibitor_123")
      expect(json["data"]["key_id"]).to eq("rzp_test_key")
    end
  end

  describe "POST /v1/public/events/:event_slug/exhibitor_payments/verify" do
    it "marks exhibitor payment as paid when signature is valid" do
      allow(Payments::RazorpayGateway).to receive(:valid_signature?).and_return(true)

      post "/v1/public/events/#{event.slug}/exhibitor_payments/verify", params: {
        exhibitor_kit_id: exhibitor_kit.id,
        razorpay_order_id: "order_exhibitor_123",
        razorpay_payment_id: "pay_exhibitor_123",
        razorpay_signature: "signature_123",
      }

      expect(response).to have_http_status(:ok)
      expect(exhibitor_kit.reload.payment_status).to eq("paid")
      expect(exhibitor_kit.exhibitor_registration_payment).to be_present
      expect(exhibitor_kit.exhibitor_registration_payment.status).to eq("paid")
    end

    it "rejects invalid payment signature" do
      allow(Payments::RazorpayGateway).to receive(:valid_signature?).and_return(false)

      post "/v1/public/events/#{event.slug}/exhibitor_payments/verify", params: {
        exhibitor_kit_id: exhibitor_kit.id,
        razorpay_order_id: "order_exhibitor_123",
        razorpay_payment_id: "pay_exhibitor_123",
        razorpay_signature: "invalid_signature",
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(exhibitor_kit.reload.payment_status).to eq("unpaid")
    end
  end
end
