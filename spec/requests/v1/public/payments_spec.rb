require "rails_helper"

RSpec.describe "V1::Public::Payments", type: :request do
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) do
    create(:ticket_type, event: event, price: 120.0, status: :published, hidden: false)
  end

  let!(:pending_ticket) do
    create(
      :ticket,
      event: event,
      ticket_type: ticket_type,
      status: :pending_payment,
      payment_status: :pending,
    )
  end

  describe "POST /v1/public/events/:event_slug/payments/create_order" do
    it "returns payment order payload for pending ticket" do
      allow(Payments::RazorpayGateway).to receive(:create_order).and_return(
        {
          "id" => "order_sandbox_123",
          "amount" => 12000,
          "currency" => "MYR",
        },
      )
      allow(Payments::RazorpayGateway).to receive(:key_id).and_return("rzp_test_key")

      post "/v1/public/events/#{event.slug}/payments/create_order", params: {
        ticket_public_id: pending_ticket.public_id,
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be(true)
      expect(json["data"]["order_id"]).to eq("order_sandbox_123")
      expect(json["data"]["key_id"]).to eq("rzp_test_key")
    end
  end

  describe "POST /v1/public/events/:event_slug/payments/verify" do
    it "marks pending ticket as paid and purchased when signature valid" do
      allow(Payments::RazorpayGateway).to receive(:valid_signature?).and_return(true)

      post "/v1/public/events/#{event.slug}/payments/verify", params: {
        ticket_public_id: pending_ticket.public_id,
        razorpay_order_id: "order_sandbox_123",
        razorpay_payment_id: "pay_sandbox_123",
        razorpay_signature: "valid_signature",
      }

      expect(response).to have_http_status(:ok)

      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq("paid")
      expect(pending_ticket.status).to eq("purchased")
    end

    it "rejects invalid signature" do
      allow(Payments::RazorpayGateway).to receive(:valid_signature?).and_return(false)

      post "/v1/public/events/#{event.slug}/payments/verify", params: {
        ticket_public_id: pending_ticket.public_id,
        razorpay_order_id: "order_sandbox_123",
        razorpay_payment_id: "pay_sandbox_123",
        razorpay_signature: "invalid_signature",
      }

      expect(response).to have_http_status(:unprocessable_content)
      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq("pending")
      expect(pending_ticket.status).to eq("pending_payment")
    end
  end

  describe "POST /v1/public/payments/webhook" do
    let(:captured_payload) do
      {
        event: "payment.captured",
        payload: {
          payment: {
            entity: {
              id: "pay_webhook_123",
              order_id: "order_webhook_123",
              notes: {
                ticket_public_id: pending_ticket.public_id,
              },
            },
          },
        },
      }
    end

    it "marks ticket paid when webhook signature is valid" do
      allow(Payments::RazorpayGateway).to receive(:valid_webhook_signature?).and_return(true)

      post "/v1/public/payments/webhook", params: captured_payload.to_json, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Razorpay-Signature" => "valid_webhook_signature",
      }

      expect(response).to have_http_status(:ok)
      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq("paid")
      expect(pending_ticket.status).to eq("purchased")
    end

    it "rejects invalid webhook signature" do
      allow(Payments::RazorpayGateway).to receive(:valid_webhook_signature?).and_return(false)

      post "/v1/public/payments/webhook", params: captured_payload.to_json, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Razorpay-Signature" => "invalid_webhook_signature",
      }

      expect(response).to have_http_status(:unprocessable_content)
      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq("pending")
      expect(pending_ticket.status).to eq("pending_payment")
    end
  end
end
