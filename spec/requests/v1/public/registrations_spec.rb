require 'rails_helper'

RSpec.describe 'V1::Public::Registrations', type: :request do
  include ActiveJob::TestHelper

  let(:event) { create(:event, status: :published) }
  let!(:ticket_type) do
    create(
      :ticket_type,
      event: event,
      name: 'General',
      price: 100.00,
      status: :published,
      hidden: false,
      custom_fields_data: {
        company_name: 'text',
        job_title: 'text'
      }
    )
  end

  describe 'GET /v1/public/events/:event_slug/ticket_types' do
    it 'returns available ticket types' do
      get "/v1/public/events/#{event.slug}/ticket_types"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']).to be_an(Array)
      expect(json['data'].first['name']).to eq('General')
      expect(json['data'].first['price'].to_f).to eq(100.0)
      expect(json['data'].first['original_price'].to_f).to eq(100.0)
      expect(json['data'].first['current_tier']).to be_nil
      expect(json['data'].first['custom_fields_data']['company_name']).to eq('text')
      expect(json['data'].first['allow_multiple_tickets_per_email']).to be false
    end

    context 'with active price tier' do
      before do
        create(:ticket_type_price_tier,
               ticket_type: ticket_type,
               label: 'Early Bird',
               price: 80.00,
               starts_at: 1.day.ago,
               ends_at: 1.day.from_now)
      end

      it 'returns the tier price' do
        get "/v1/public/events/#{event.slug}/ticket_types"

        json = JSON.parse(response.body)
        expect(json['data'].first['price'].to_f).to eq(80.0)
        expect(json['data'].first['original_price'].to_f).to eq(100.0)
        expect(json['data'].first['current_tier']).to eq('Early Bird')
      end
    end

    context 'when quantity is limited' do
      before { ticket_type.update!(quantity: 2) }

      it 'calculates remaining_slots using paid tickets only' do
        create(
          :ticket,
          event: event,
          ticket_type: ticket_type,
          attendee_email: 'paid@example.com',
          status: :purchased,
          payment_status: :paid
        )

        create(
          :ticket,
          event: event,
          ticket_type: ticket_type,
          attendee_email: 'pending@example.com',
          status: :pending_payment,
          payment_status: :pending
        )

        get "/v1/public/events/#{event.slug}/ticket_types"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data'].first['remaining_slots']).to eq(1)
      end
    end
  end

  describe 'GET /v1/public/events/:event_slug/registration_forms' do
    let!(:form_with_custom_labels) do
      create(
        :registration_form,
        event: event,
        name: 'Delegate',
        slug: 'delegate',
        custom_labels_data: [
          { 'key' => 'company_name', 'label' => 'Company Name' },
          { 'key' => 'dietary_requirements', 'label' => 'Dietary Requirements' }
        ]
      )
    end

    it 'returns custom labels for each registration form' do
      get "/v1/public/events/#{event.slug}/registration_forms"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      matching_form = json['data'].find { |f| f['slug'] == 'delegate' }

      expect(matching_form).to be_present
      expect(matching_form['custom_labels_data']).to eq(
        [
          { 'key' => 'company_name', 'label' => 'Company Name' },
          { 'key' => 'dietary_requirements', 'label' => 'Dietary Requirements' }
        ]
      )
    end
  end

  describe 'GET /v1/public/events/:event_slug/pass_bundles/:token' do
    let!(:delegate_form) do
      form = create(:registration_form, event: event, name: 'Invited Delegate', slug: 'invited-delegate')
      form.ticket_types << ticket_type
      form
    end
    let!(:pass_bundle) do
      create(
        :pass_bundle,
        event: event,
        registration_form: delegate_form,
        ticket_type: ticket_type,
        name: 'STB Delegation',
        pass_limit: 2,
        payment_mode: :pay_offline,
        payment_status: :unpaid,
        status: :active
      )
    end

    it 'returns the registration context for a valid bundle link' do
      get "/v1/public/events/#{event.slug}/pass_bundles/#{pass_bundle.token}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['data']).to include(
        'name' => 'STB Delegation',
        'pass_limit' => 2,
        'used_count' => 0,
        'remaining_count' => 2,
        'registration_form' => include(
          'name' => 'Invited Delegate',
          'slug' => 'invited-delegate'
        ),
        'ticket_type' => include(
          'id' => ticket_type.id,
          'name' => 'General'
        )
      )
    end

    it 'rejects invalid bundle tokens' do
      get "/v1/public/events/#{event.slug}/pass_bundles/not-real"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['message']).to eq('Invalid or expired bundle link.')
    end

    it 'rejects unavailable bundle links' do
      pass_bundle.update!(status: :paused)

      get "/v1/public/events/#{event.slug}/pass_bundles/#{pass_bundle.token}"

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('This bundle is paused. Please contact the organizer.')
    end
  end

  describe 'GET /v1/public/events/:event_slug/registration_status' do
    let!(:other_ticket_type) do
      create(:ticket_type, event: event, name: 'Other', price: 50.00, status: :published, hidden: false)
    end

    let!(:delegate_form) do
      form = create(:registration_form, event: event, name: 'Delegate', slug: 'delegate')
      form.ticket_types << ticket_type
      form
    end

    let!(:pending_ticket) do
      create(
        :ticket,
        event: event,
        ticket_type: ticket_type,
        attendee_email: 'john@example.com',
        registered_by_email: 'leader@example.com',
        status: :pending_payment,
        payment_status: :pending,
        custom_fields_data: { 'registration_mode' => 'delegate' }
      )
    end

    let!(:paid_ticket) do
      create(
        :ticket,
        event: event,
        ticket_type: ticket_type,
        attendee_email: 'john@example.com',
        status: :purchased,
        payment_status: :paid,
        custom_fields_data: { 'registration_mode' => 'delegate' }
      )
    end

    let!(:other_form_ticket) do
      create(
        :ticket,
        event: event,
        ticket_type: other_ticket_type,
        attendee_email: 'john@example.com',
        status: :pending_payment,
        payment_status: :pending,
        custom_fields_data: { 'registration_mode' => 'other_form' }
      )
    end

    it 'returns pending and paid registration state for an email' do
      get "/v1/public/events/#{event.slug}/registration_status", params: {
        email: 'john@example.com',
        form_slug: 'delegate'
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be(true)
      expect(json['data']['has_pending_payment']).to be(true)
      expect(json['data']['has_paid_ticket']).to be(true)
      expect(json['data']['pending_tickets'].map { |t| t['public_id'] }).to include(pending_ticket.public_id)
      expect(json['data']['pending_tickets'].find do |t|
        t['public_id'] == pending_ticket.public_id
      end['registered_by_email']).to eq('leader@example.com')
      expect(json['data']['pending_tickets'].find do |t|
        t['public_id'] == pending_ticket.public_id
      end['payment_proof_uploaded']).to be(false)
      expect(json['data']['pending_tickets'].map { |t| t['public_id'] }).not_to include(other_form_ticket.public_id)
      expect(json['data']['paid_tickets'].map { |t| t['public_id'] }).to include(paid_ticket.public_id)
    end

    it 'reports when a pending ticket already has payment proof' do
      payment = pending_ticket.create_ticket_payment!(amount: ticket_type.current_price, status: :pending)
      payment.payment_proof.attach(fixture_file_upload('test_image.png', 'image/png'))

      get "/v1/public/events/#{event.slug}/registration_status", params: {
        email: 'john@example.com',
        form_slug: 'delegate'
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      pending = json['data']['pending_tickets'].find { |ticket| ticket['public_id'] == pending_ticket.public_id }

      expect(pending['payment_proof_uploaded']).to be(true)
    end

    it 'returns 422 when email is blank' do
      get "/v1/public/events/#{event.slug}/registration_status", params: { email: '' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not treat purchased tickets with pending payment_status as payable' do
      stale_ticket = create(
        :ticket,
        event: event,
        ticket_type: ticket_type,
        attendee_email: 'stale@example.com',
        status: :purchased,
        payment_status: :pending,
        custom_fields_data: { 'registration_mode' => 'delegate' }
      )

      get "/v1/public/events/#{event.slug}/registration_status", params: {
        email: 'stale@example.com',
        form_slug: 'delegate'
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be(true)
      expect(json['data']['has_pending_payment']).to be(false)
      expect(json['data']['pending_tickets'].map { |t| t['public_id'] }).not_to include(stale_ticket.public_id)
    end

    it 'returns rejected application state for rejected delegate applications' do
      rejected_ticket = create(
        :ticket,
        event: event,
        ticket_type: ticket_type,
        attendee_email: 'rejected@example.com',
        status: :canceled,
        payment_status: :pending
      )
      create(
        :ticket_application,
        ticket: rejected_ticket,
        registration_form: delegate_form,
        review_status: :rejected,
        rejection_reason: 'Limited seats'
      )

      get "/v1/public/events/#{event.slug}/registration_status", params: {
        email: 'rejected@example.com',
        form_slug: 'delegate'
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be(true)
      expect(json['data']['has_rejected_application']).to be(true)
      expect(json['data']['rejected_message']).to include('not selected')
    end
  end

  describe 'POST /v1/public/events/:event_slug/register' do
    let(:valid_params) do
      {
        attendee_name: 'John Doe',
        attendee_email: 'john@example.com',
        attendee_phone: '0123456789',
        ticket_type_id: ticket_type.id,
        role: 'delegate',
        custom_fields_data: {
          company: 'Acme Energy',
          job_title: 'Engineer',
          registration_kind: 'member'
        }
      }
    end

    context 'when the ticket type is sold out' do
      before { ticket_type.update!(quantity: 1) }

      it 'rejects registration even via direct API call, bypassing any frontend check' do
        create(
          :ticket,
          event: event,
          ticket_type: ticket_type,
          attendee_email: 'first@example.com',
          status: :purchased,
          payment_status: :paid
        )

        expect do
          post "/v1/public/events/#{event.slug}/register", params: valid_params
        end.not_to change(Ticket, :count)

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['code']).to eq('ticket_sold_out')
      end
    end

    context 'when registration form delegate approval is enabled' do
      let!(:interested_form) do
        form = create(:registration_form, event: event, name: 'Interested Delegate', slug: 'interested-delegate')
        form.ticket_types << ticket_type
        form
      end

      before do
        create(:registration_form_rsvp_setting,
               registration_form: interested_form,
               enabled: true,
               rsvp_required: true,
               review_sla_hours: 48)
        ActionMailer::Base.deliveries.clear
        clear_enqueued_jobs
        clear_performed_jobs
      end

      it 'creates a pending ticket application and sends acknowledgement' do
        perform_enqueued_jobs do
          expect do
            post "/v1/public/events/#{event.slug}/register",
                 params: valid_params.merge(form_slug: interested_form.slug)
          end.to change(Ticket, :count).by(1)
            .and change(TicketApplication, :count).by(1)
        end

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first
        application = created_ticket.ticket_application

        expect(created_ticket.status).to eq('pending_payment')
        expect(created_ticket.payment_status).to eq('pending')
        expect(application.review_status).to eq('pending_review')
        expect(application.rsvp_status).to eq('not_sent')
        expect(application.registration_form_id).to eq(interested_form.id)
        expect(ActionMailer::Base.deliveries.last.subject).to include('Application received for')
        expect(ActionMailer::Base.deliveries.map(&:subject).join(' ')).not_to include('Your ticket for')
      end

      it 'blocks re-registration for previously rejected applicants on the same form' do
        rejected_ticket = create(
          :ticket,
          event: event,
          ticket_type: ticket_type,
          attendee_email: 'john@example.com',
          status: :canceled,
          payment_status: :pending
        )
        create(
          :ticket_application,
          ticket: rejected_ticket,
          registration_form: interested_form,
          review_status: :rejected,
          rejection_reason: 'Limited seats'
        )

        expect do
          post "/v1/public/events/#{event.slug}/register",
               params: valid_params.merge(form_slug: interested_form.slug)
        end.not_to change(Ticket, :count)

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['message']).to include('application was not selected in this intake')
      end
    end

    context 'when the registration form is on waiting_list status' do
      let!(:waiting_list_form) do
        form = create(:registration_form, event: event, name: 'Waiting List Form', slug: 'waiting-list-form', status: :waiting_list)
        form.ticket_types << ticket_type
        form
      end

      it 'creates a waiting-list ticket instead of rejecting the registration' do
        expect do
          post "/v1/public/events/#{event.slug}/register",
               params: valid_params.merge(form_slug: waiting_list_form.slug)
        end.to change(Ticket, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['waiting_list']).to eq(true)

        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.waiting_list).to eq(true)
        expect(created_ticket.status).to eq('pending_payment')
        expect(created_ticket.payment_status).to eq('pending')
      end
    end

    context 'when the registration form is closed' do
      let!(:closed_form) do
        form = create(:registration_form, event: event, name: 'Closed Form', slug: 'closed-form', status: :closed)
        form.ticket_types << ticket_type
        form
      end

      it 'rejects the registration without creating a ticket' do
        expect do
          post "/v1/public/events/#{event.slug}/register",
               params: valid_params.merge(form_slug: closed_form.slug)
        end.not_to change(Ticket, :count)

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Registration is closed for this form')
      end
    end

    it 'creates a new ticket' do
      expect do
        post "/v1/public/events/#{event.slug}/register", params: valid_params
      end.to change(Ticket, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['attendee_name']).to eq('John Doe')
      expect(json['data']['payment_status']).to eq('pending')
      expect(json['data']['role']).to eq('delegate')
      expect(json['data']['custom_fields_data']['company']).to eq('Acme Energy')

      created_ticket = Ticket.order(created_at: :desc).first
      expect(created_ticket.status).to eq('pending_payment')
    end

    context 'with free ticket type' do
      before { ticket_type.update!(price: 0) }

      it 'sets payment_status to paid' do
        post "/v1/public/events/#{event.slug}/register", params: valid_params

        json = JSON.parse(response.body)
        expect(json['data']['payment_status']).to eq('paid')

        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('purchased')
      end

      it 'keeps ticket pending when it belongs to a group checkout' do
        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          registered_by_email: 'leader@example.com'
        )

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['payment_status']).to eq('pending')

        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('pending_payment')
      end

      it 'marks rm0 group member as paid when leader is already paid' do
        paid_leader_ticket_type = create(:ticket_type, event: event, price: 6000, status: :published, hidden: false)
        create(
          :ticket,
          event: event,
          ticket_type: paid_leader_ticket_type,
          attendee_name: 'Leader',
          attendee_email: 'leader@example.com',
          registered_by_email: 'leader@example.com',
          status: :purchased,
          payment_status: :paid
        )

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          attendee_email: 'member-new@example.com',
          registered_by_email: 'leader@example.com'
        )

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['payment_status']).to eq('paid')

        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('purchased')
      end
    end

    context 'with missing required fields' do
      it 'returns validation errors' do
        post "/v1/public/events/#{event.slug}/register", params: { ticket_type_id: ticket_type.id }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when event is not published' do
      before { event.update!(status: :draft) }

      it 'returns an error' do
        post "/v1/public/events/#{event.slug}/register", params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['message']).to include('not open')
      end
    end

    context 'for Borneo Expo conference registration' do
      let(:event) { create(:event, slug: 'borneo-expo-2026', status: :published) }
      let!(:conference_ticket_type) do
        create(:ticket_type, event: event, name: 'Conference Pass', price: 100.00, status: :published, hidden: false)
      end
      let!(:combined_ticket_type) do
        create(:ticket_type, event: event, name: 'Exhibitor & Conference', price: 100.00, status: :published,
                             hidden: false)
      end
      let!(:conference_form) do
        form = create(:registration_form, event: event, name: 'Conference', slug: 'conference')
        form.ticket_types << conference_ticket_type
        form
      end

      let(:valid_params) do
        super().merge(ticket_type_id: conference_ticket_type.id, form_slug: 'conference')
      end

      it 'returns conference upgrade data for an existing exhibitor ticket' do
        exhibitor_ticket_type = create(
          :ticket_type,
          event: event,
          name: 'Premium Exhibitor Access',
          price: 100.00,
          status: :published,
          hidden: false
        )
        existing_ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_name: 'Existing Name',
          attendee_email: 'JOHN@example.com',
          attendee_phone: '0000000000',
          status: :purchased,
          payment_status: :paid
        )

        get "/v1/public/events/#{event.slug}/registration_status", params: {
          email: 'john@example.com',
          form_slug: 'conference'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['upgrade_mode']).to be(true)
        expect(json['data']['upgrade_target']).to eq('conference')
        expect(json['data']['existing_ticket_public_id']).to eq(existing_ticket.public_id)
        expect(json['data']['existing_attendee_name']).to eq('Existing Name')
        expect(json['data']['existing_attendee_email']).to eq('JOHN@example.com')
        expect(json['data']['existing_attendee_phone']).to eq('0000000000')
        expect(json['data']['existing_ticket_type']).to eq('Premium Exhibitor Access')
      end

      it 'does not enter conference upgrade mode for unpaid exhibitor tickets' do
        exhibitor_ticket_type = create(
          :ticket_type,
          event: event,
          name: 'Premium Exhibitor Access',
          price: 100.00,
          status: :published,
          hidden: false
        )
        create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_name: 'Pending Exhibitor',
          attendee_email: 'john@example.com',
          attendee_phone: '0000000000',
          status: :pending_payment,
          payment_status: :pending
        )

        get "/v1/public/events/#{event.slug}/registration_status", params: {
          email: 'john@example.com',
          form_slug: 'conference'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['upgrade_mode']).to be(false)
        expect(json['data']['upgrade_target']).to be_nil
        expect(json['data']['existing_ticket_public_id']).to be_nil
        expect(json['data']['blocked_exhibitor_upgrade']).to be(true)
        expect(json['data']['blocked_reason']).to eq('unpaid_exhibitor')
        expect(json['data']['blocked_message']).to eq('You already have an unpaid exhibitor registration. Please complete that payment first before registering for conference.')
      end

      it 'reuses an existing exhibitor ticket for payment without upgrading it yet' do
        exhibitor_ticket_type = create(
          :ticket_type,
          event: event,
          name: 'Premium Exhibitor Access',
          price: 100.00,
          status: :published,
          hidden: false
        )
        existing_ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_name: 'Existing Name',
          attendee_email: 'john@example.com',
          attendee_phone: '0000000000',
          role: 'Existing Exhibitor',
          status: :purchased,
          payment_status: :paid
        )

        expect do
          post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
            attendee_name: 'Ignored Name',
            attendee_phone: '9999999999',
            role: 'Ignored Role'
          )
        end.not_to change(Ticket, :count)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['data']['public_id']).to eq(existing_ticket.public_id)
        expect(existing_ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
        expect(existing_ticket.attendee_name).to eq('Existing Name')
        expect(existing_ticket.attendee_phone).to eq('0000000000')
        expect(existing_ticket.role).to eq('Existing Exhibitor')
      end

      it 'reuses the existing exhibitor ticket for conference-like plural form slugs' do
        conference_form.update!(slug: 'conferences')

        exhibitor_ticket_type = create(
          :ticket_type,
          event: event,
          name: 'Premium Exhibitor Access',
          price: 100.00,
          status: :published,
          hidden: false
        )
        existing_ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_name: 'Existing Name',
          attendee_email: 'john@example.com',
          attendee_phone: '0000000000',
          role: 'Exhibitor',
          status: :purchased,
          payment_status: :paid
        )

        expect do
          post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(form_slug: 'conferences')
        end.not_to change(Ticket, :count)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['public_id']).to eq(existing_ticket.public_id)
        expect(existing_ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
      end

      it 'still creates a new conference ticket when no exhibitor ticket exists' do
        expect do
          post "/v1/public/events/#{event.slug}/register", params: valid_params
        end.to change(Ticket, :count).by(1)

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first

        expect(created_ticket.ticket_type).to eq(conference_ticket_type)
        expect(created_ticket.status).to eq('pending_payment')
        expect(created_ticket.payment_status).to eq('pending')
      end

      it 'creates a new conference ticket instead of reusing an unpaid exhibitor ticket' do
        exhibitor_ticket_type = create(
          :ticket_type,
          event: event,
          name: 'Premium Exhibitor Access',
          price: 100.00,
          status: :published,
          hidden: false
        )
        existing_ticket = create(
          :ticket,
          event: event,
          ticket_type: exhibitor_ticket_type,
          attendee_name: 'Existing Name',
          attendee_email: 'john@example.com',
          attendee_phone: '0000000000',
          role: 'Exhibitor',
          status: :pending_payment,
          payment_status: :pending
        )

        expect do
          post "/v1/public/events/#{event.slug}/register", params: valid_params
        end.to change(Ticket, :count).by(1)

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first

        expect(created_ticket).not_to eq(existing_ticket)
        expect(created_ticket.ticket_type).to eq(conference_ticket_type)
        expect(existing_ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
      end

      it 'still creates a new ticket for non-Borneo events' do
        other_event = create(:event, slug: 'other-event-2026', status: :published)
        other_conference_ticket_type = create(
          :ticket_type,
          event: other_event,
          name: 'Conference Pass',
          price: 100.00,
          status: :published,
          hidden: false
        )
        create(
          :ticket_type,
          event: other_event,
          name: 'Exhibitor & Conference',
          price: 100.00,
          status: :published,
          hidden: false
        )
        other_form = create(:registration_form, event: other_event, name: 'Conference', slug: 'conference')
        other_form.ticket_types << other_conference_ticket_type
        exhibitor_ticket_type = create(
          :ticket_type,
          event: other_event,
          name: 'Premium Exhibitor Access',
          price: 100.00,
          status: :published,
          hidden: false
        )
        existing_ticket = create(
          :ticket,
          event: other_event,
          ticket_type: exhibitor_ticket_type,
          attendee_email: 'john@example.com',
          status: :purchased,
          payment_status: :paid
        )

        expect do
          post "/v1/public/events/#{other_event.slug}/register",
               params: valid_params.merge(ticket_type_id: other_conference_ticket_type.id)
        end.to change(Ticket, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(existing_ticket.reload.ticket_type).to eq(exhibitor_ticket_type)
      end
    end

    context 'with pass bundle token' do
      let!(:delegate_form) do
        form = create(:registration_form, event: event, name: 'Delegate', slug: 'delegate')
        form.ticket_types << ticket_type
        form
      end
      let!(:pass_bundle) do
        create(
          :pass_bundle,
          event: event,
          registration_form: delegate_form,
          ticket_type: ticket_type,
          name: 'STB',
          pass_limit: 2,
          payment_mode: :pay_offline,
          payment_status: :unpaid,
          status: :active
        )
      end

      it 'stamps created ticket with the pass bundle' do
        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.pass_bundle).to eq(pass_bundle)
      end

      it 'does not let bundle payment status block registration' do
        pass_bundle.update!(payment_status: :unpaid)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:created)
      end

      it 'creates a paid ticket when bundle payment_status is not_required' do
        pass_bundle.update!(payment_mode: :free, payment_status: :not_required)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('purchased')
        expect(created_ticket.payment_status).to eq('paid')
      end

      it 'creates a paid ticket when bundle payment_status is sponsored' do
        pass_bundle.update!(payment_status: :sponsored)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('purchased')
        expect(created_ticket.payment_status).to eq('paid')
      end

      it 'creates a paid ticket when bundle payment_status is paid' do
        pass_bundle.update!(payment_status: :paid)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('purchased')
        expect(created_ticket.payment_status).to eq('paid')
      end

      it 'creates a pending ticket when bundle payment_status is unpaid' do
        pass_bundle.update!(payment_mode: :pay_offline, payment_status: :unpaid)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:created)
        created_ticket = Ticket.order(created_at: :desc).first
        expect(created_ticket.status).to eq('pending_payment')
        expect(created_ticket.payment_status).to eq('pending')
      end

      it 'rejects an invalid bundle token' do
        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: 'not-real'
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('Invalid or expired bundle link.')
      end

      it 'rejects a paused bundle' do
        pass_bundle.update!(status: :paused)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('This bundle is paused. Please contact the organizer.')
      end

      it 'rejects an expired bundle' do
        pass_bundle.update!(expires_at: 1.day.ago)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('Invalid or expired bundle link.')
      end

      it 'rejects a full bundle' do
        create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: pass_bundle)
        create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: pass_bundle)

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('This bundle is full. Please contact the organizer.')
      end

      it 'rejects registration form mismatch' do
        visitor_form = create(:registration_form, event: event, name: 'Visitor', slug: 'visitor')
        visitor_form.ticket_types << ticket_type

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'visitor',
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('This bundle link is not valid for this registration form.')
      end

      it 'rejects selected pass mismatch' do
        other_ticket_type = create(:ticket_type, event: event, name: 'VIP', status: :published, hidden: false)
        delegate_form.ticket_types << other_ticket_type

        post "/v1/public/events/#{event.slug}/register", params: valid_params.merge(
          form_slug: 'delegate',
          ticket_type_id: other_ticket_type.id,
          bundle: pass_bundle.token
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['message']).to eq('This bundle link is not valid for the selected pass.')
      end
    end
  end

  # =========================================================================
  # Form-scoped registration (form_slug filtering)
  # =========================================================================

  context 'with registration form mapping' do
    let!(:conference_ticket) do
      create(:ticket_type, event: event, name: 'Conference Pass', price: 200.00, status: :published, hidden: false)
    end
    let!(:visitor_ticket) do
      create(:ticket_type, event: event, name: 'Visitor Pass', price: 0, status: :published, hidden: false)
    end

    let!(:conference_form) do
      form = create(:registration_form, event: event, name: 'Conference', slug: 'conference')
      create(
        :registration_form_ticket_type,
        registration_form: form,
        ticket_type: conference_ticket,
        registration_mode: :group,
        min_attendees: 3,
        max_attendees: 10,
        custom_labels_data: [
          { 'key' => 'member_id', 'label' => 'Member ID' }
        ]
      )
      form
    end
    let!(:visitor_form) do
      form = create(:registration_form, event: event, name: 'Visitor', slug: 'visitor')
      form.ticket_types << visitor_ticket
      form
    end

    describe 'GET /v1/public/events/:event_slug/ticket_types?form_slug=conference' do
      it 'returns only ticket types mapped to the conference form' do
        get "/v1/public/events/#{event.slug}/ticket_types", params: { form_slug: 'conference' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        names = json['data'].map { |tt| tt['name'] }
        expect(names).to include('Conference Pass')
        expect(names).not_to include('Visitor Pass')

        conference_response = json['data'].find { |tt| tt['id'] == conference_ticket.id }
        expect(conference_response['registration_mode']).to eq('group')
        expect(conference_response['min_attendees']).to eq(3)
        expect(conference_response['max_attendees']).to eq(10)
        expect(conference_response['custom_labels_data']).to eq(
          [
            { 'key' => 'member_id', 'label' => 'Member ID' }
          ]
        )
      end

      it 'returns 404 for unknown form slug' do
        get "/v1/public/events/#{event.slug}/ticket_types", params: { form_slug: 'nonexistent' }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'POST /v1/public/events/:event_slug/register with form_slug' do
      it 'rejects ticket type not mapped to the specified form' do
        post "/v1/public/events/#{event.slug}/register", params: {
          form_slug: 'visitor',
          ticket_type_id: conference_ticket.id,
          attendee_name: 'Jane Doe',
          attendee_email: 'jane@example.com',
          attendee_phone: '0123456789'
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['message']).to include('not allowed')
      end

      it 'succeeds with valid form + ticket combination' do
        post "/v1/public/events/#{event.slug}/register", params: {
          form_slug: 'visitor',
          ticket_type_id: visitor_ticket.id,
          attendee_name: 'Jane Doe',
          attendee_email: 'jane@example.com',
          attendee_phone: '0123456789'
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['attendee_name']).to eq('Jane Doe')
      end
    end
  end
end
