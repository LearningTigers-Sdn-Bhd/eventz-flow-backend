require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorPayments', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:booth_price) do
    create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', label: 'Malaysian', price: 1500.00)
  end
  let(:exhibitor_kit) do
    exhibitor.exhibitor_kit.tap do |kit|
      kit.update!(
        exhibitor_booth_price: booth_price,
        amount_paid: 1500.00,
        payment_status: :unpaid
      )
    end
  end

  let(:gateway_instance) { instance_double(Payments::RazorpayGateway, key_id: 'rzp_test_key') }

  before do
    allow(Payments::RazorpayGateway).to receive(:for_event).and_return(gateway_instance)
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_payments/create_order' do
    it 'creates a razorpay order for unpaid exhibitor kit' do
      allow(gateway_instance).to receive(:create_order).and_return(
        {
          'id' => 'order_exhibitor_123',
          'amount' => 150_000,
          'currency' => 'MYR'
        }
      )

      post "/v1/public/events/#{event.slug}/exhibitor_payments/create_order",
           params: { exhibitor_kit_id: exhibitor_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['order_id']).to eq('order_exhibitor_123')
      expect(json['data']['key_id']).to eq('rzp_test_key')
    end

    it 'creates a fresh razorpay order when the previous attempt failed' do
      create(
        :exhibitor_registration_payment,
        exhibitor_kit: exhibitor_kit,
        status: 'failed',
        gateway_response: {
          'id' => 'pay_failed_123',
          'order_id' => 'order_failed_123',
          'amount' => 150_000,
          'method' => 'fpx'
        }
      )

      allow(gateway_instance).to receive(:create_order).and_return(
        {
          'id' => 'order_exhibitor_retry_456',
          'amount' => 150_000,
          'currency' => 'MYR'
        }
      )

      post "/v1/public/events/#{event.slug}/exhibitor_payments/create_order",
           params: { exhibitor_kit_id: exhibitor_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['order_id']).to eq('order_exhibitor_retry_456')
      expect(exhibitor_kit.reload.exhibitor_registration_payment.status).to eq('pending')
      expect(exhibitor_kit.exhibitor_registration_payment.gateway_response['id']).to eq('order_exhibitor_retry_456')
    end
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_payments/verify' do
    it 'marks exhibitor payment as paid when signature is valid' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_exhibitor_123').and_return(
        { 'id' => 'pay_exhibitor_123', 'order_id' => 'order_exhibitor_123', 'method' => 'fpx' }
      )

      post "/v1/public/events/#{event.slug}/exhibitor_payments/verify", params: {
        exhibitor_kit_id: exhibitor_kit.id,
        razorpay_order_id: 'order_exhibitor_123',
        razorpay_payment_id: 'pay_exhibitor_123',
        razorpay_signature: 'signature_123'
      }

      expect(response).to have_http_status(:ok)
      expect(exhibitor_kit.reload.payment_status).to eq('paid')
      expect(exhibitor_kit.exhibitor_registration_payment).to be_present
      expect(exhibitor_kit.exhibitor_registration_payment.status).to eq('paid')
      expect(exhibitor_kit.exhibitor_registration_payment.payment_method).to eq('fpx')
    end

    it 'rejects invalid payment signature' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(false)

      post "/v1/public/events/#{event.slug}/exhibitor_payments/verify", params: {
        exhibitor_kit_id: exhibitor_kit.id,
        razorpay_order_id: 'order_exhibitor_123',
        razorpay_payment_id: 'pay_exhibitor_123',
        razorpay_signature: 'invalid_signature'
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(exhibitor_kit.reload.payment_status).to eq('unpaid')
    end
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_payments/callback' do
    it 'redirects to the event public registration URL on successful callback' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_exhibitor_123').and_return(
        { 'id' => 'pay_exhibitor_123', 'order_id' => 'order_exhibitor_123', 'method' => 'card' }
      )

      post "/v1/public/events/#{event.slug}/exhibitor_payments/callback", params: {
        exhibitor_kit_id: exhibitor_kit.id,
        razorpay_order_id: 'order_exhibitor_123',
        razorpay_payment_id: 'pay_exhibitor_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('https://forms.example.com/exhibitor-registration?step=success')
      expect(exhibitor_kit.reload.exhibitor_registration_payment.payment_method).to eq('card')
    end
  end
end
