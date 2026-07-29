require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorPayments', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:kit) { create(:exhibitor_kit, event_vendor: exhibitor, price_snapshot: 1500, currency: 'MYR') }
  let(:access) { PublicExhibitorAccessSession.issue_challenge!(event: event, email: vendor.email) }
  let(:token) { access.first.exchange_challenge!(access.last) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let(:gateway) { instance_double(Payments::RazorpayGateway, key_id: 'key') }

  before { allow(Payments::RazorpayGateway).to receive(:for_event).and_return(gateway) }

  it 'binds order to owned public booking and reuses matching unexpired order' do
    expect(gateway).to receive(:create_order).once.with(
      amount_subunits: 150_000,
      receipt: "exh_#{kit.public_id.delete('-')}",
      notes: { type: 'exhibitor_registration', event_slug: event.slug, booking_public_id: kit.public_id }
    ).and_return(
      'id' => 'order_1', 'amount' => 150_000, 'currency' => 'MYR'
    )
    2.times do
      post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_order", headers: headers
      expect(response).to have_http_status(:ok)
    end
    expect(kit.reload.exhibitor_registration_payment.gateway_order_id).to eq('order_1')
  end

  it 'returns 404 for a sibling account booking' do
    foreign = create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event))
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{foreign.public_id}/payment_order", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'requires stored order, amount, currency, status, and unique gateway payment' do
    create(:exhibitor_registration_payment, exhibitor_kit: kit, amount: 1500, currency: 'MYR',
      gateway_order_id: 'order_1', order_expires_at: 10.minutes.from_now)
    allow(gateway).to receive(:valid_signature?).and_return(true)
    allow(gateway).to receive(:fetch_payment).and_return(
      'id' => 'pay_1', 'order_id' => 'order_1', 'amount' => 150_000,
      'currency' => 'MYR', 'status' => 'captured', 'method' => 'fpx'
    )

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_verifications",
      params: { razorpay_order_id: 'order_1', razorpay_payment_id: 'pay_1', razorpay_signature: 'signature' },
      headers: headers

    expect(response).to have_http_status(:ok)
    expect(kit.reload).to be_paid
    expect(kit.exhibitor_registration_payment.gateway_payment_id).to eq('pay_1')
  end

  it 'returns safe errors without gateway exception messages' do
    allow(gateway).to receive(:valid_signature?).and_raise('secret upstream response')
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_verifications",
      params: { razorpay_order_id: 'order_1', razorpay_payment_id: 'pay_1', razorpay_signature: 'signature' },
      headers: headers
    expect(response.body).not_to include('secret upstream response')
    expect(response.parsed_body['code']).to eq('payment_verification_failed')
  end

  it 'rejects payment order creation for an expired reservation' do
    kit.update!(reservation_expires_at: 1.minute.ago)

    expect(gateway).not_to receive(:create_order)
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_order", headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['code']).to eq('booking_expired')
  end

  it 'rejects verification when reservation expires before payment is locked' do
    create(:exhibitor_registration_payment, exhibitor_kit: kit, amount: 1500, currency: 'MYR',
      gateway_order_id: 'order_1', order_expires_at: 10.minutes.from_now)
    kit.update!(reservation_expires_at: 1.minute.ago)
    allow(gateway).to receive(:valid_signature?).and_return(true)
    allow(gateway).to receive(:fetch_payment).and_return(
      'id' => 'pay_1', 'order_id' => 'order_1', 'amount' => 150_000,
      'currency' => 'MYR', 'status' => 'captured', 'method' => 'fpx'
    )

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_verifications",
      params: { razorpay_order_id: 'order_1', razorpay_payment_id: 'pay_1', razorpay_signature: 'signature' },
      headers: headers

    expect(response.parsed_body['code']).to eq('booking_expired')
    expect(kit.reload).not_to be_paid
  end

  it 'returns already_paid on repeated verification without another confirmation email' do
    payment = create(:exhibitor_registration_payment, exhibitor_kit: kit, amount: 1500, currency: 'MYR',
      status: 'paid', gateway_order_id: 'order_1', gateway_payment_id: 'pay_1', paid_at: Time.current)
    kit.update!(payment_status: :paid, booking_status: :paid)
    allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_verifications",
      params: { razorpay_order_id: payment.gateway_order_id, razorpay_payment_id: payment.gateway_payment_id,
                razorpay_signature: 'signature' }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'already_paid')).to be(true)
    expect(EmailDelivery::AuditedDelivery).not_to have_received(:deliver_later)
  end

  it 'returns already_paid when payment completes before verification acquires its locks' do
    payment = create(:exhibitor_registration_payment, exhibitor_kit: kit, amount: 1500, currency: 'MYR',
      gateway_order_id: 'order_1', order_expires_at: 10.minutes.from_now)
    allow(gateway).to receive(:valid_signature?).and_return(true)
    allow(gateway).to receive(:fetch_payment).and_return(
      'id' => 'pay_1', 'order_id' => 'order_1', 'amount' => 150_000,
      'currency' => 'MYR', 'status' => 'captured', 'method' => 'fpx'
    )
    allow_any_instance_of(ExhibitorKit).to receive(:lock!).and_wrap_original do |method, *args|
      payment.update!(status: 'paid', gateway_payment_id: 'pay_1', paid_at: Time.current)
      kit.update!(payment_status: :paid, booking_status: :paid)
      method.call(*args)
    end

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_verifications",
      params: { razorpay_order_id: 'order_1', razorpay_payment_id: 'pay_1', razorpay_signature: 'signature' },
      headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'already_paid')).to be(true)
  end
end
