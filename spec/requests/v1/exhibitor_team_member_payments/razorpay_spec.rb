# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::ExhibitorTeamMemberPayments::Razorpay', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true, use_ticket: true, user: org_owner) }
  let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:kit) { exhibitor.exhibitor_kit }

  let(:gateway_instance) do
    instance_double(Payments::RazorpayGateway, key_id: 'rzp_test_key')
  end
  let(:headers) { {} }

  before do
    create(:exhibitor_team_member_limit, event: event, team_member_limit: 1, extra_team_member_fee: 50.0)

    EventPaymentGateway.create!(
      event: event,
      provider: 'razorpay',
      key_id: 'rzp_test_key',
      key_secret: 'secret',
      webhook_secret: 'webhook_secret'
    )

    allow(Payments::RazorpayGateway).to receive(:for_event).and_return(gateway_instance)
  end

  describe 'POST /v1/events/:event_id/exhibitor_kits/:kit_id/exhibitor_team_member_payments/razorpay/create_order' do
    let(:url) { "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}/exhibitor_team_member_payments/razorpay/create_order" }

    context 'as vendor with excess team members' do
      let(:headers) { auth_headers(vendor) }

      it 'creates a Razorpay order and pending payment record' do
        allow(gateway_instance).to receive(:create_order).and_return(
          { 'id' => 'order_extra_123', 'amount' => 5000, 'currency' => 'MYR' }
        )

        expect { post url, headers: headers }.to change(ExhibitorTeamMemberPayment, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['order_id']).to eq('order_extra_123')
        expect(json['data']['key_id']).to eq('rzp_test_key')
        expect(json['data']['amount']).to eq(5000)
        expect(json['data']['callback_url']).to include('/callback')

        payment = ExhibitorTeamMemberPayment.last
        expect(payment.status).to eq('pending')
        expect(payment.payment_source).to eq('payment_gateway')
        expect(payment.gateway).to eq('razorpay')
        expect(payment.gateway_response).to include('id' => 'order_extra_123')
        expect(payment.extra_member_count).to eq(1)
        expect(payment.amount).to eq(50.0)
      end

      it 'reuses existing pending payment_gateway payment' do
        existing = kit.exhibitor_team_member_payments.create!(
          extra_member_count: 1,
          fee_per_member: 50.0,
          amount: 50.0,
          status: :pending,
          payment_source: :payment_gateway,
          gateway: 'razorpay',
          gateway_response: { 'id' => 'order_old_123' }
        )

        allow(gateway_instance).to receive(:create_order).and_return(
          { 'id' => 'order_new_456', 'amount' => 5000, 'currency' => 'MYR' }
        )

        expect { post url, headers: headers }.not_to change(ExhibitorTeamMemberPayment, :count)

        expect(response).to have_http_status(:ok)
        existing.reload
        expect(existing.gateway_response).to include('id' => 'order_new_456')
      end

      it 'returns error when no excess team members' do
        kit.exhibitor_team_members.order(:id).last.destroy!

        post url, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when event has no payment gateway configured' do
      let(:headers) { auth_headers(vendor) }

      before { event.event_payment_gateway.destroy! }

      it 'returns error' do
        post url, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to include('payment gateway')
      end
    end

    context 'as organizer (not vendor)' do
      let(:headers) { auth_headers(org_owner) }

      it 'returns forbidden' do
        post url, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_kits/:kit_id/exhibitor_team_member_payments/razorpay/verify' do
    let!(:payment) do
      kit.exhibitor_team_member_payments.create!(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: 'razorpay',
        gateway_response: { 'id' => 'order_extra_123', 'amount' => 5000 }
      )
    end
    let(:url) { "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}/exhibitor_team_member_payments/razorpay/verify" }

    let(:headers) { auth_headers(vendor) }

    it 'verifies payment with valid Razorpay signature' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)

      post url, params: {
        payment_id: payment.id,
        razorpay_order_id: 'order_extra_123',
        razorpay_payment_id: 'pay_extra_123',
        razorpay_signature: 'valid_signature'
      }, headers: headers

      expect(response).to have_http_status(:ok)
      payment.reload
      expect(payment.status).to eq('verified')
      expect(payment.gateway_payment_id).to eq('pay_extra_123')
      expect(payment.gateway_response).to include('payment_id' => 'pay_extra_123')
      expect(payment.paid_at).to be_present
      expect(payment.payee_id).to eq(vendor.id)
    end

    it 'rejects invalid Razorpay signature' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(false)

      post url, params: {
        payment_id: payment.id,
        razorpay_order_id: 'order_extra_123',
        razorpay_payment_id: 'pay_extra_123',
        razorpay_signature: 'invalid_signature'
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      payment.reload
      expect(payment.status).to eq('pending')
    end

    it 'rejects verification when order id does not match the stored order' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)

      post url, params: {
        payment_id: payment.id,
        razorpay_order_id: 'order_other_999',
        razorpay_payment_id: 'pay_extra_123',
        razorpay_signature: 'valid_signature'
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('Payment order mismatch')
      payment.reload
      expect(payment.status).to eq('pending')
    end

    it 'rejects verification when stored order amount does not match payment amount' do
      payment.update!(gateway_response: { 'id' => 'order_extra_123', 'amount' => 9999 })
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)

      post url, params: {
        payment_id: payment.id,
        razorpay_order_id: 'order_extra_123',
        razorpay_payment_id: 'pay_extra_123',
        razorpay_signature: 'valid_signature'
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('Payment amount mismatch')
      payment.reload
      expect(payment.status).to eq('pending')
    end

    it 'is idempotent when payment already verified' do
      payment.update!(status: :verified, gateway_payment_id: 'pay_extra_123', paid_at: Time.current)

      post url, params: {
        payment_id: payment.id,
        razorpay_order_id: 'order_extra_123',
        razorpay_payment_id: 'pay_extra_123',
        razorpay_signature: 'valid_signature'
      }, headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /v1/events/:event_id/exhibitor_kits/:kit_id/exhibitor_team_member_payments/razorpay/callback' do
    let!(:payment) do
      kit.exhibitor_team_member_payments.create!(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: 'razorpay',
        gateway_response: { 'id' => 'order_extra_123', 'amount' => 5000 }
      )
    end
    let(:url) do
      "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}/exhibitor_team_member_payments/razorpay/callback?payment_id=#{payment.id}&razorpay_order_id=order_extra_123&razorpay_payment_id=pay_extra_123&razorpay_signature=valid_signature"
    end

    it 'redirects back to team members page and verifies payment' do
      original = ENV['REDIRECT_BASE_URL']
      ENV['REDIRECT_BASE_URL'] = 'http://localhost:3001'
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)

      get url

      expect(response).to have_http_status(:found)
      expect(response.location).to eq(
        "http://localhost:3001/event/#{event.id}/team-members?payment=success&source=extra-team-member"
      )

      payment.reload
      expect(payment.status).to eq('verified')
      expect(payment.gateway_payment_id).to eq('pay_extra_123')
      expect(payment.payee_id).to eq(vendor.id)
    ensure
      ENV['REDIRECT_BASE_URL'] = original
    end

    it 'redirects back with error when signature is invalid' do
      original = ENV['REDIRECT_BASE_URL']
      ENV['REDIRECT_BASE_URL'] = 'http://localhost:3001'
      allow(gateway_instance).to receive(:valid_signature?).and_return(false)

      get url

      expect(response).to have_http_status(:found)
      expect(response.location).to eq(
        "http://localhost:3001/event/#{event.id}/team-members?payment=error&source=extra-team-member&reason=invalid_signature"
      )

      payment.reload
      expect(payment.status).to eq('pending')
    ensure
      ENV['REDIRECT_BASE_URL'] = original
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_kits/:kit_id/exhibitor_team_member_payments/razorpay/callback' do
    let!(:payment) do
      kit.exhibitor_team_member_payments.create!(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: 'razorpay',
        gateway_response: { 'id' => 'order_extra_123', 'amount' => 5000 }
      )
    end
    let(:url) do
      "/v1/events/#{event.id}/exhibitor_kits/#{kit.id}/exhibitor_team_member_payments/razorpay/callback"
    end

    it 'accepts POST callback redirects from Razorpay and verifies payment' do
      original = ENV['REDIRECT_BASE_URL']
      ENV['REDIRECT_BASE_URL'] = 'http://localhost:3001'
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)

      post url, params: {
        payment_id: payment.id,
        razorpay_order_id: 'order_extra_123',
        razorpay_payment_id: 'pay_extra_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to eq(
        "http://localhost:3001/event/#{event.id}/team-members?payment=success&source=extra-team-member"
      )

      payment.reload
      expect(payment.status).to eq('verified')
      expect(payment.gateway_payment_id).to eq('pay_extra_123')
    ensure
      ENV['REDIRECT_BASE_URL'] = original
    end
  end

  describe 'route scoping' do
    let(:headers) { auth_headers(vendor) }
    let(:other_event) { create(:event, status: :published, use_exhibitor_kit: true, use_ticket: true, user: org_owner) }

    it 'does not resolve exhibitor kits from another event id' do
      post "/v1/events/#{other_event.id}/exhibitor_kits/#{kit.id}/exhibitor_team_member_payments/razorpay/create_order",
           headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
