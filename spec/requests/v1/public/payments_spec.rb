require 'rails_helper'

RSpec.describe 'V1::Public::Payments', type: :request do
  include ActiveJob::TestHelper

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

    it 'creates a payment order for a borneo conference upgrade without upgrading the exhibitor ticket yet' do
      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        role: 'Exhibitor',
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        status: :purchased,
        payment_status: :paid
      )

      allow(gateway_instance).to receive(:create_order).and_return(
        {
          'id' => 'order_borneo_upgrade_123',
          'amount' => 12_000,
          'currency' => 'MYR',
          'notes' => {
            'ticket_public_id' => existing_ticket.public_id,
            'upgrade_target' => 'conference'
          }
        }
      )

      post "/v1/public/events/#{borneo_event.slug}/payments/create_order", params: {
        ticket_public_id: existing_ticket.public_id
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['already_paid']).not_to be(true)
      expect(json['data']['order_id']).to eq('order_borneo_upgrade_123')
      expect(existing_ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
    end

    it 'charges a conference upgrade using the selected conference ticket price and stores the originating form slug' do
      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      conference_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Conference Pass',
        price: 80.0,
        status: :published,
        hidden: false
      )
      combined_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      conference_form = create(:registration_form, event: borneo_event, name: 'Conferences', slug: 'conferences')
      conference_form.ticket_types << conference_ticket_type
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        role: 'Custom Exhibitor Role',
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        status: :purchased,
        payment_status: :paid
      )

      expect(gateway_instance).to receive(:create_order).with(
        amount_subunits: 8_000,
        receipt: existing_ticket.public_id,
        notes: {
          event_slug: borneo_event.slug,
          ticket_public_id: existing_ticket.public_id,
          upgrade_target: 'conference',
          form_slug: 'conferences',
          conference_ticket_type_id: conference_ticket_type.id.to_s
        }
      ).and_return(
        {
          'id' => 'order_borneo_upgrade_456',
          'amount' => 8_000,
          'currency' => 'MYR'
        }
      )

      post "/v1/public/events/#{borneo_event.slug}/payments/create_order", params: {
        ticket_public_id: existing_ticket.public_id,
        form_slug: 'conferences',
        ticket_type_id: conference_ticket_type.id
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['amount']).to eq(8_000)
      expect(existing_ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
      expect(combined_ticket_type.current_price.to_f).to eq(120.0)
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

    it 'upgrades a borneo exhibitor ticket to the combined type only after successful verification' do
      ActionMailer::Base.deliveries.clear

      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      combined_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        role: 'Custom Exhibitor Role',
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        status: :purchased,
        payment_status: :paid
      )

      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_upgrade_123').and_return(
        {
          'id' => 'pay_upgrade_123',
          'order_id' => 'order_upgrade_123',
          'method' => 'card',
          'notes' => {
            'ticket_public_id' => existing_ticket.public_id,
            'upgrade_target' => 'conference'
          }
        }
      )

      clear_enqueued_jobs

      perform_enqueued_jobs do
        post "/v1/public/events/#{borneo_event.slug}/payments/verify", params: {
          ticket_public_id: existing_ticket.public_id,
          razorpay_order_id: 'order_upgrade_123',
          razorpay_payment_id: 'pay_upgrade_123',
          razorpay_signature: 'valid_signature'
        }
      end

      expect(response).to have_http_status(:ok)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.body.encoded).to include('Exhibitor & Conference')

      existing_ticket.reload
      expect(existing_ticket.ticket_type).to eq(combined_ticket_type)
      expect(existing_ticket.public_id).to be_present
      expect(existing_ticket.payment_status).to eq('paid')
      expect(existing_ticket.status).to eq('purchased')
      expect(existing_ticket.role).to eq('Custom Exhibitor Role')
    end

    it 'marks conference-upgrade verification as paid and purchased even if the source exhibitor ticket was pending' do
      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      combined_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        role: 'Custom Exhibitor Role',
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        status: :pending_payment,
        payment_status: :pending
      )

      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_upgrade_pending_123').and_return(
        {
          'id' => 'pay_upgrade_pending_123',
          'order_id' => 'order_upgrade_pending_123',
          'method' => 'card',
          'notes' => {
            'ticket_public_id' => existing_ticket.public_id,
            'upgrade_target' => 'conference'
          }
        }
      )

      post "/v1/public/events/#{borneo_event.slug}/payments/verify", params: {
        ticket_public_id: existing_ticket.public_id,
        razorpay_order_id: 'order_upgrade_pending_123',
        razorpay_payment_id: 'pay_upgrade_pending_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json.dig('data', 'payment_status')).to eq('paid')
      expect(json.dig('data', 'status')).to eq('purchased')

      existing_ticket.reload
      expect(existing_ticket.ticket_type).to eq(combined_ticket_type)
      expect(existing_ticket.payment_status).to eq('paid')
      expect(existing_ticket.status).to eq('purchased')
      expect(existing_ticket.role).to eq('Custom Exhibitor Role')
      expect(existing_ticket.ticket_payment).to be_present
    end

    it 'does not upgrade a borneo exhibitor ticket when verification fails' do
      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        role: 'Custom Exhibitor Role',
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        status: :purchased,
        payment_status: :paid
      )

      allow(gateway_instance).to receive(:valid_signature?).and_return(false)

      post "/v1/public/events/#{borneo_event.slug}/payments/verify", params: {
        ticket_public_id: existing_ticket.public_id,
        razorpay_order_id: 'order_upgrade_123',
        razorpay_payment_id: 'pay_upgrade_123',
        razorpay_signature: 'invalid_signature'
      }

      expect(response).to have_http_status(:unprocessable_content)

      existing_ticket.reload
      expect(existing_ticket.ticket_type).to eq(exhibitor_ticket_type)
      expect(existing_ticket.payment_status).to eq('paid')
      expect(existing_ticket.status).to eq('purchased')
    end
  end

  describe 'POST /v1/public/events/:event_slug/payments/callback' do
    it 'redirects to the event public registration URL on successful callback' do
      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_sandbox_123').and_return(
        { 'id' => 'pay_sandbox_123', 'order_id' => 'order_sandbox_123', 'method' => 'fpx' }
      )

      post "/v1/public/events/#{event.slug}/payments/callback", params: {
        ticket_public_id: pending_ticket.public_id,
        razorpay_order_id: 'order_sandbox_123',
        razorpay_payment_id: 'pay_sandbox_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('https://forms.example.com/register/standard?step=success')
      expect(pending_ticket.reload.ticket_payment.payment_method).to eq('fpx')
    end

    it 'redirects borneo conference-upgrade payments to the conference form path without changing role' do
      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      combined_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      conference_form = create(:registration_form, event: borneo_event, name: 'Conference', slug: 'conference')
      conference_form.ticket_types << combined_ticket_type
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        role: 'Custom Exhibitor Role',
        status: :purchased,
        payment_status: :paid
      )

      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_upgrade_123').and_return(
        {
          'id' => 'pay_upgrade_123',
          'order_id' => 'order_upgrade_123',
          'method' => 'fpx',
          'notes' => {
            'ticket_public_id' => existing_ticket.public_id,
            'upgrade_target' => 'conference'
          }
        }
      )

      post "/v1/public/events/#{borneo_event.slug}/payments/callback", params: {
        ticket_public_id: existing_ticket.public_id,
        razorpay_order_id: 'order_upgrade_123',
        razorpay_payment_id: 'pay_upgrade_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('https://forms.example.com/register/conference?step=success')

      existing_ticket.reload
      expect(existing_ticket.ticket_type).to eq(combined_ticket_type)
      expect(existing_ticket.role).to eq('Custom Exhibitor Role')
    end

    it 'redirects borneo conference-upgrade payments back to the originating conference-like form slug' do
      borneo_event = create(:event, slug: 'borneo-expo-2026', status: :published)
      exhibitor_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Premium Exhibitor Access',
        price: 120.0,
        status: :published,
        hidden: false
      )
      combined_ticket_type = create(
        :ticket_type,
        event: borneo_event,
        name: 'Exhibitor & Conference',
        price: 120.0,
        status: :published,
        hidden: false
      )
      conference_form = create(:registration_form, event: borneo_event, name: 'Conferences', slug: 'conferences')
      conference_form.ticket_types << combined_ticket_type
      existing_ticket = create(
        :ticket,
        event: borneo_event,
        ticket_type: exhibitor_ticket_type,
        attendee_name: 'Existing Exhibitor',
        attendee_email: 'exhibitor@example.com',
        role: 'Premium Exhibitor Access',
        status: :purchased,
        payment_status: :paid
      )

      allow(gateway_instance).to receive(:valid_signature?).and_return(true)
      allow(gateway_instance).to receive(:fetch_payment).with('pay_upgrade_slug_123').and_return(
        {
          'id' => 'pay_upgrade_slug_123',
          'order_id' => 'order_upgrade_slug_123',
          'method' => 'fpx',
          'notes' => {
            'ticket_public_id' => existing_ticket.public_id,
            'upgrade_target' => 'conference',
            'form_slug' => 'conferences'
          }
        }
      )

      post "/v1/public/events/#{borneo_event.slug}/payments/callback", params: {
        ticket_public_id: existing_ticket.public_id,
        razorpay_order_id: 'order_upgrade_slug_123',
        razorpay_payment_id: 'pay_upgrade_slug_123',
        razorpay_signature: 'valid_signature'
      }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('https://forms.example.com/register/conferences?step=success')
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

    it 'uses the event-specific gateway when exhibitor webhook notes include event_slug' do
      gateway_event = create(:event, status: :published)
      vendor = create(:user, :vendor, email: 'event-gateway@example.com')
      exhibitor = create(:exhibitor, event: gateway_event, vendor: vendor)
      booth_price = create(:exhibitor_booth_price, event: gateway_event, booth_type: 'shell_scheme',
                                                   label: 'Premium', price: 1800)
      exhibitor_kit = exhibitor.exhibitor_kit
      exhibitor_kit.update!(
        exhibitor_booth_price: booth_price,
        amount_paid: 1800,
        payment_status: :unpaid
      )

      payload = {
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: 'pay_exhibitor_gateway_123',
              order_id: 'order_exhibitor_gateway_123',
              method: 'card',
              notes: {
                type: 'exhibitor_registration',
                event_slug: gateway_event.slug,
                exhibitor_kit_id: exhibitor_kit.id
              }
            }
          }
        }
      }

      allow(Payments::RazorpayGateway).to receive(:for_event).with(gateway_event).and_return(gateway_instance)
      allow(gateway_instance).to receive(:valid_webhook_signature?).and_return(true)

      post '/v1/public/payments/webhook', params: payload.to_json, headers: {
        'CONTENT_TYPE' => 'application/json',
        'X-Razorpay-Signature' => 'valid_webhook_signature'
      }

      expect(response).to have_http_status(:ok)
      expect(Payments::RazorpayGateway).to have_received(:for_event).with(gateway_event)
      exhibitor_kit.reload
      expect(exhibitor_kit.payment_status).to eq('paid')
    end

    it 'returns ok and keeps exhibitor registration paid when payment.captured is replayed' do
      vendor = create(:user, :vendor, email: 'replay@example.com')
      exhibitor = create(:exhibitor, event: event, vendor: vendor)
      booth_price = create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', label: 'Replay',
                                                   price: 2000)
      exhibitor_kit = exhibitor.exhibitor_kit
      exhibitor_kit.update!(
        exhibitor_booth_price: booth_price,
        amount_paid: 2000,
        payment_status: :paid
      )
      exhibitor_kit.create_exhibitor_registration_payment!(
        gateway: 'razorpay',
        amount: 2000,
        status: :paid,
        gateway_payment_id: 'pay_exhibitor_replay_123',
        payment_method: 'card',
        gateway_response: {
          'id' => 'pay_exhibitor_replay_123',
          'order_id' => 'order_exhibitor_replay_123',
          'method' => 'card'
        }
      )

      payload = {
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: 'pay_exhibitor_replay_123',
              order_id: 'order_exhibitor_replay_123',
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
      expect(exhibitor_kit.payment_status).to eq('paid')
      expect(exhibitor_kit.exhibitor_registration_payment.status).to eq('paid')
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
