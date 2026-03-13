require 'rails_helper'

RSpec.describe 'V1::Public::Payments', type: :request do
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
      payment_status: :pending
    )
  end

  let(:gateway_instance) { instance_double(Payments::RazorpayGateway, key_id: 'rzp_test_key') }

  before do
    allow(Payments::RazorpayGateway).to receive(:for_event).and_return(gateway_instance)
    allow(Payments::RazorpayGateway).to receive(:default).and_return(gateway_instance)
  end

  describe 'POST /v1/public/events/:event_slug/payments/create_order' do
    it 'returns payment order payload for pending ticket' do
      allow(gateway_instance).to receive(:create_order).and_return(
        {
          'id' => 'order_sandbox_123',
          'amount' => 12_000,
          'currency' => 'MYR'
        }
      )

      post "/v1/public/events/#{event.slug}/payments/create_order", params: {
        ticket_public_id: pending_ticket.public_id
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['order_id']).to eq('order_sandbox_123')
      expect(json['data']['key_id']).to eq('rzp_test_key')
    end

    it 'charges group once when member tickets are free' do
      free_member_ticket_type = create(:ticket_type, event: event, price: 0, status: :published, hidden: false)
      leader_email = 'leader@golf.com'

      pending_ticket.update!(registered_by_email: leader_email, attendee_email: leader_email)

      create(
        :ticket,
        event: event,
        ticket_type: free_member_ticket_type,
        attendee_name: 'Member One',
        attendee_email: 'member1@golf.com',
        registered_by_email: leader_email,
        status: :pending_payment,
        payment_status: :pending
      )

      expect(gateway_instance).to receive(:create_order).with(
        hash_including(amount_subunits: 12_000)
      ).and_return(
        {
          'id' => 'order_sandbox_group_123',
          'amount' => 12_000,
          'currency' => 'MYR'
        }
      )

      post "/v1/public/events/#{event.slug}/payments/create_order", params: {
        ticket_public_id: pending_ticket.public_id
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['amount']).to eq(12_000)
    end
  end

  describe 'POST /v1/public/events/:event_slug/payments/verify' do
    it 'marks pending ticket as paid and purchased when signature valid' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_sandbox_123').and_return(
        { 'id' => 'pay_sandbox_123', 'order_id' => 'order_sandbox_123', 'method' => 'card' }
      )

      post "/v1/public/events/#{event.slug}/payments/verify", params: {
        ticket_public_id: pending_ticket.public_id,
        razorpay_order_id: 'order_sandbox_123',
        razorpay_payment_id: 'pay_sandbox_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:ok)

      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq('paid')
      expect(pending_ticket.status).to eq('purchased')
      expect(pending_ticket.ticket_payment.payment_method).to eq('card')
    end

    it 'rejects invalid signature' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(false)

      post "/v1/public/events/#{event.slug}/payments/verify", params: {
        ticket_public_id: pending_ticket.public_id,
        razorpay_order_id: 'order_sandbox_123',
        razorpay_payment_id: 'pay_sandbox_123',
        razorpay_signature: 'invalid_signature'
      }

      expect(response).to have_http_status(:unprocessable_content)
      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq('pending')
      expect(pending_ticket.status).to eq('pending_payment')
    end
  end

  describe 'POST /v1/public/events/:event_slug/payments/callback' do
    it 'redirects to FRONTEND_FORM_URL on successful callback' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_sandbox_123').and_return(
        { 'id' => 'pay_sandbox_123', 'order_id' => 'order_sandbox_123', 'method' => 'fpx' }
      )
      original = ENV['FRONTEND_FORM_URL']
      ENV['FRONTEND_FORM_URL'] = 'https://forms.example.com'

      post "/v1/public/events/#{event.slug}/payments/callback", params: {
        ticket_public_id: pending_ticket.public_id,
        razorpay_order_id: 'order_sandbox_123',
        razorpay_payment_id: 'pay_sandbox_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('https://forms.example.com/register/standard?step=success')
      expect(pending_ticket.reload.ticket_payment.payment_method).to eq('fpx')
    ensure
      ENV['FRONTEND_FORM_URL'] = original
    end
  end

  describe 'POST /v1/public/payments/webhook' do
    let(:captured_payload) do
      {
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: 'pay_webhook_123',
              order_id: 'order_webhook_123',
              method: 'upi',
              notes: {
                ticket_public_id: pending_ticket.public_id
              }
            }
          }
        }
      }
    end

    it 'marks ticket paid when webhook signature is valid' do
      allow(gateway_instance).to receive(:valid_webhook_signature?).and_return(true)

      post '/v1/public/payments/webhook', params: captured_payload.to_json, headers: {
        'CONTENT_TYPE' => 'application/json',
        'X-Razorpay-Signature' => 'valid_webhook_signature'
      }

      expect(response).to have_http_status(:ok)
      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq('paid')
      expect(pending_ticket.status).to eq('purchased')
      expect(pending_ticket.ticket_payment.payment_method).to eq('upi')
    end

    it 'rejects invalid webhook signature' do
      allow(gateway_instance).to receive(:valid_webhook_signature?).and_return(false)

      post '/v1/public/payments/webhook', params: captured_payload.to_json, headers: {
        'CONTENT_TYPE' => 'application/json',
        'X-Razorpay-Signature' => 'invalid_webhook_signature'
      }

      expect(response).to have_http_status(:unprocessable_content)
      pending_ticket.reload
      expect(pending_ticket.payment_status).to eq('pending')
      expect(pending_ticket.status).to eq('pending_payment')
    end

    it 'marks exhibitor registration payment as paid for exhibitor webhook notes' do
      vendor = create(:user, :vendor, email: 'exhibitor@example.com')
      exhibitor = create(:exhibitor, event: event, vendor: vendor)
      booth_price = create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', label: 'Malaysian',
                                                   price: 1500)
      exhibitor_kit = exhibitor.exhibitor_kit
      exhibitor_kit.update!(
        exhibitor_booth_price: booth_price,
        amount_paid: 1500,
        payment_status: :unpaid
      )

      payload = {
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: 'pay_exhibitor_webhook_123',
              order_id: 'order_exhibitor_webhook_123',
              method: 'card',
              notes: {
                type: 'exhibitor_registration',
                exhibitor_kit_id: exhibitor_kit.id
              }
            }
          }
        }
      }

      allow(gateway_instance).to receive(:valid_webhook_signature?).and_return(true)

      post '/v1/public/payments/webhook', params: payload.to_json, headers: {
        'CONTENT_TYPE' => 'application/json',
        'X-Razorpay-Signature' => 'valid_webhook_signature'
      }

      expect(response).to have_http_status(:ok)
      exhibitor_kit.reload
      payment = exhibitor_kit.exhibitor_registration_payment

      expect(exhibitor_kit.payment_status).to eq('paid')
      expect(payment).to be_present
      expect(payment.status).to eq('paid')
      expect(payment.gateway_payment_id).to eq('pay_exhibitor_webhook_123')
      expect(payment.payment_method).to eq('card')
    end

    context 'extra_team_member payment type' do
      let(:extra_team_member_event) { create(:event, status: :published, use_exhibitor_kit: true) }
      let(:vendor) { create(:user, :vendor) }
      let(:exhibitor) { create(:exhibitor, event: extra_team_member_event, vendor: vendor) }
      let(:kit) { exhibitor.exhibitor_kit }
      let!(:payment) do
        kit.exhibitor_team_member_payments.create!(
          extra_member_count: 1,
          fee_per_member: 50.0,
          amount: 50.0,
          status: :pending,
          payment_source: :payment_gateway,
          gateway: 'razorpay',
          gateway_response: { 'id' => 'order_extra_webhook_123', 'amount' => 5000 }
        )
      end

      before do
        EventPaymentGateway.create!(
          event: extra_team_member_event,
          provider: 'razorpay',
          key_id: 'rzp_extra_key',
          key_secret: 'secret',
          webhook_secret: 'webhook_secret'
        )
      end

      it 'marks extra team member payment as verified on payment.captured webhook' do
        allow(gateway_instance).to receive(:valid_webhook_signature?).and_return(true)

        payload = {
          event: 'payment.captured',
          payload: {
            payment: {
              entity: {
                id: 'pay_webhook_extra_123',
                order_id: 'order_extra_webhook_123',
                method: 'card',
                notes: {
                  type: 'extra_team_member',
                  event_slug: extra_team_member_event.slug,
                  payment_id: payment.id.to_s
                }
              }
            }
          }
        }

        post '/v1/public/payments/webhook', params: payload.to_json, headers: {
          'CONTENT_TYPE' => 'application/json',
          'X-Razorpay-Signature' => 'valid_sig'
        }

        expect(response).to have_http_status(:ok)
        payment.reload
        expect(payment.status).to eq('verified')
        expect(payment.gateway_payment_id).to eq('pay_webhook_extra_123')
        expect(payment.payment_method).to eq('card')
        expect(payment.paid_at).to be_present
      end

      it 'marks extra team member payment as rejected on payment.failed webhook' do
        allow(gateway_instance).to receive(:valid_webhook_signature?).and_return(true)

        payload = {
          event: 'payment.failed',
          payload: {
            payment: {
              entity: {
                id: 'pay_webhook_extra_fail',
                order_id: 'order_extra_webhook_123',
                notes: {
                  type: 'extra_team_member',
                  event_slug: extra_team_member_event.slug,
                  payment_id: payment.id.to_s
                }
              }
            }
          }
        }

        post '/v1/public/payments/webhook', params: payload.to_json, headers: {
          'CONTENT_TYPE' => 'application/json',
          'X-Razorpay-Signature' => 'valid_sig'
        }

        expect(response).to have_http_status(:ok)
        payment.reload
        expect(payment.status).to eq('rejected')
      end
    end
  end
end
