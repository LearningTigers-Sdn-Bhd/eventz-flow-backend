# tickets_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS (Defined as Global Constants for RSwag compatibility) 💡
# =========================================================================

# The full Ticket schema used for POST, GET/:id, PATCH, and PATCH check_in success responses.
TICKET_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer, readOnly: true, description: 'Internal database ID' },
    public_id: { type: :string, format: :uuid, description: 'The unique ID used for scanning/check-in.' },
    attendee_name: { type: :string },
    attendee_email: { type: :string, format: :email },
    attendee_phone: { type: [:string, :null] },
    status: { type: :string, enum: ['purchased', 'scanned', 'refunded', 'canceled', 'pending_payment'] },
    payment_status: { type: :string, enum: ['pending', 'paid', 'failed', 'refunded_payment'] },
    checked_in: { type: :boolean, readOnly: true },
    custom_fields_data: { type: :object, description: 'E.g., {"t_shirt_size": "L"}' },
    event_id: { type: :integer, readOnly: true },
    ticket_type_id: { type: :integer },
    ticket_type: {
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        price: { type: :string, description: 'Price as decimal string' }
      }
    }
  },
  required: ['public_id', 'attendee_name', 'attendee_email', 'status', 'payment_status', 'event_id', 'ticket_type_id'],
  additionalProperties: true
}.freeze

# The minimal schema for the index array response (/v1/events/:event_id/tickets GET).
TICKET_INDEX_ITEM_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    public_id: { type: :string, format: :uuid },
    attendee_name: { type: :string },
    status: { type: :string, enum: ['purchased', 'scanned', 'refunded', 'canceled', 'pending_payment'] },
    ticket_type: {
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        price: { type: :string, description: 'Price as decimal string' }
      }
    }
  },
  additionalProperties: true
}.freeze


RSpec.describe 'V1::Tickets', type: :request do
  # --- Setup Users & Tokens (UNCHANGED) ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user, :member) }
  let(:staff_user) { create(:user, :staff_member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event (Controlled by Organizer) (UNCHANGED) ---
  let!(:organizer_event) do
    event = create(:event, title: 'Organizer Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  # --- Setup Ticket Type (required for Tickets) (UNCHANGED) ---
  let!(:general_ticket_type) { create(:ticket_type, event: organizer_event, name: 'GA') }

  # --- Setup Tickets (UNCHANGED) ---
  let!(:purchased_ticket) do
    create(:ticket, event: organizer_event, ticket_type: general_ticket_type, status: :purchased, attendee_name: 'Purchased Attendee')
  end
  let!(:checked_in_ticket) do
    ticket = create(:ticket, event: organizer_event, ticket_type: general_ticket_type, checked_in: true, check_in_at: Time.current, status: :scanned, attendee_name: 'Scanned Attendee')
    create(:scan_log, event: organizer_event, scannable: ticket,
                      scanned_at: ticket.check_in_at, scanned_by: staff_user)
    ticket
  end
  let(:paid_purchased_ticket) do
    create(:ticket, event: organizer_event, ticket_type: general_ticket_type, status: :purchased, payment_status: :paid, attendee_name: 'Paid Purchased Attendee')
  end
  let(:paid_checked_in_ticket) do
    create(:ticket, event: organizer_event, ticket_type: general_ticket_type, status: :scanned, checked_in: true, check_in_at: Time.current, payment_status: :paid, attendee_name: 'Paid Scanned Attendee')
  end
  let(:pending_payment_ticket) do
    create(
      :ticket,
      event: organizer_event,
      ticket_type: general_ticket_type,
      status: :pending_payment,
      payment_status: :pending,
      attendee_name: 'Pending Payment Attendee'
    )
  end
  let(:valid_ticket_params) do
    {
      ticket: {
        attendee_name: 'New Ticket Holder',
        attendee_email: 'new.holder@example.com',
        ticket_type_id: general_ticket_type.id,
        custom_fields_data: { t_shirt_size: 'L' }
      }
    }
  end

  # =========================================================================
  # Routes scoped under an event: /v1/events/:event_id/tickets
  # =========================================================================

  path '/v1/events/{event_id}/tickets' do
    parameter name: :event_id, in: :path, type: :integer, description: 'ID of the parent Event'

    # --- GET - Index ---
    get 'Lists all tickets for a specific event' do
      tags 'Tickets'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :archived, in: :query, type: :string, required: false, description: 'Set to "true" to show only archived tickets'
      parameter name: :full, in: :query, type: :string, required: false, description: 'Set to "true" to show all tickets including archived ones'

      let(:event_id) { organizer_event.id }

      response '200', 'Returns list of tickets for authorized staff' do
        let(:Authorization) { "Bearer #{staff_token}" } # Staff can view tickets for their event
        before do
          pass_bundle = create(
            :pass_bundle,
            event: organizer_event,
            registration_form: create(:registration_form, event: organizer_event, slug: 'delegate'),
            ticket_type: general_ticket_type,
            name: 'STB'
          )
          purchased_ticket.update!(pass_bundle: pass_bundle)
          create(:ticket_application, ticket: pending_payment_ticket, review_status: :approved, rsvp_status: :sent)
          pending_payment_ticket
        end

        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(3)
          bundle_ticket = json.find { |ticket| ticket['id'] == purchased_ticket.id }
          expect(bundle_ticket['pass_bundle']).to include('id', 'name')
          expect(bundle_ticket['pass_bundle']['name']).to eq('STB')
          pending_payload = json.find { |ticket| ticket['public_id'] == pending_payment_ticket.public_id }
          expect(pending_payload['ticket_application']).to include(
            'review_status' => 'approved',
            'rsvp_status' => 'sent'
          )
        end

        # REFACTORED: Use reusable schema constant
        schema type: :array, items: TICKET_INDEX_ITEM_SCHEMA
      end

      response '403', 'Forbidden for unauthorized member user' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end

      # Show only archived tickets
      response '200', 'Lists only archived tickets' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:archived) { 'true' }

        before do
          purchased_ticket.archive
        end

        schema type: :array, items: TICKET_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Should only see archived tickets
          expect(json.count).to be >= 1
          json.each do |ticket|
            expect(ticket['deleted_at']).not_to be_nil
          end
        end
      end

      # Show all tickets including archived
      response '200', 'Lists all tickets including archived' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:full) { 'true' }

        before do
          purchased_ticket.archive
        end

        schema type: :array, items: TICKET_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Should see both active and archived tickets
          expect(json.count).to be >= 2
          has_archived = json.any? { |ticket| ticket['deleted_at'].present? }
          has_active = json.any? { |ticket| ticket['deleted_at'].nil? }
          expect(has_archived).to be true
          expect(has_active).to be true
        end
      end
    end

    # --- POST - Create ---
    post 'Creates a new ticket (Staff Manual Entry)' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      # IMPROVED: Inline schema refined for documentation clarity
      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              attendee_name: { type: :string, example: 'John Doe' },
              attendee_email: { type: :string, format: :email, example: 'john.doe@example.com' },
              attendee_phone: { type: :string, example: '+1234567890' },
              ticket_type_id: { type: :integer, description: 'ID of the ticket type being purchased/issued' },
              custom_fields_data: { type: :object }
            },
            # IMPROVED: Added ticket_type_id to required fields for logic completeness
            required: ['attendee_name', 'attendee_email', 'ticket_type_id']
          }
        },
        required: ['ticket']
      }

      let(:event_id) { organizer_event.id }
      let(:ticket) { valid_ticket_params }

      response '201', 'Ticket created by Organizer (event admin)' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA

        run_test! do
          expect(Ticket.count).to eq(3)
        end
      end

      response '201', 'Ticket created by Org Owner' do
        let(:Authorization) { "Bearer #{org_owner_token}" }

        schema TICKET_SCHEMA

        run_test! do
          expect(Ticket.count).to eq(3)
        end
      end

      response '403', 'Forbidden for event staff (Team Member)' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '201', 'Creates a registration batch of N tickets when quantity > 1 and the event allows it' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:ticket) do
          {
            ticket: valid_ticket_params[:ticket].merge(payment_status: 1),
            quantity: 3
          }
        end

        before do
          organizer_event.update!(allow_multiple_tickets_per_email: true)
          allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later)
        end

        schema TICKET_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['group_public_ids'].size).to eq(3)
          batch_id = Ticket.find_by(public_id: json['public_id']).registration_batch_id
          expect(batch_id).to be_present
          expect(Ticket.where(registration_batch_id: batch_id).count).to eq(3)

          # One batched email with all 3 QR codes, not 3 individual ones.
          expect(EmailDelivery::AuditedDelivery).to have_received(:deliver_later).with(
            hash_including(mailer_action: 'group_confirmation_email')
          ).once
          expect(EmailDelivery::AuditedDelivery).not_to have_received(:deliver_later).with(
            hash_including(mailer_action: 'confirmation_email')
          )
        end
      end

      response '422', 'Rejects quantity greater than 1 when the event does not allow multiple tickets per email' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:ticket) { valid_ticket_params.merge(quantity: 3) }

        run_test! do
          expect(response).to have_http_status(:unprocessable_content)
          expect(Ticket.count).to eq(2)
        end
      end
    end
  end

  # =========================================================================
  # Routes for specific ticket actions: /v1/events/:event_id/tickets/:id
  # =========================================================================

  path '/v1/events/{event_id}/tickets/{id}' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'

    # --- GET - Show ---
    get 'Retrieves a specific ticket' do
      tags 'Tickets'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { organizer_event.id }
      let(:id) { purchased_ticket.public_id }

      response '200', 'Ticket found and viewable by staff' do
        let(:Authorization) { "Bearer #{staff_token}" }

        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA

        run_test!
      end

      response '403', 'Not found by member user' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end

    # ---------------------------------------------------------------------
    # --- PATCH - Update ---
    # ---------------------------------------------------------------------
    patch 'Updates a specific ticket' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      # IMPROVED: Inline request body schema
      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              attendee_name: { type: :string, example: 'Updated Name' },
              attendee_email: { type: :string, format: :email, example: 'new_email@example.com' },
              attendee_phone: { type: :string, example: '+1234567890' },
              payment_status: { type: :string, enum: ['pending', 'paid', 'failed', 'refunded_payment'] }
            }
          }
        }
      }

      let(:event_id) { organizer_event.id }
      let(:id) { purchased_ticket.public_id }
      let(:ticket) { { ticket: { attendee_name: 'Updated Name', attendee_email: 'update@example.com' } } }

      response '200', 'Ticket successfully updated by staff' do
        let(:Authorization) { "Bearer #{staff_token}" }

        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA

        run_test!
      end

      response '200', 'Pending payment ticket becomes purchased when marked paid' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:id) { pending_payment_ticket.public_id }
        let(:ticket) { { ticket: { payment_status: 'paid' } } }

        schema TICKET_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['payment_status']).to eq('paid')
          expect(json['status']).to eq('purchased')
          expect(pending_payment_ticket.reload.status).to eq('purchased')
        end
      end

      response '200', 'Paid, purchased ticket reverts to pending payment when un-paid' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:id) { paid_purchased_ticket.public_id }
        let(:ticket) { { ticket: { payment_status: 'pending' } } }

        schema TICKET_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['payment_status']).to eq('pending')
          expect(json['status']).to eq('pending_payment')
          expect(paid_purchased_ticket.reload.status).to eq('pending_payment')
        end
      end

      response '422', 'Cannot un-pay a ticket that has already been checked in' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:id) { paid_checked_in_ticket.public_id }
        let(:ticket) { { ticket: { payment_status: 'pending' } } }

        run_test! do
          expect(paid_checked_in_ticket.reload.payment_status).to eq('paid')
        end
      end

      response '200', 'Approving one ticket in a registration batch auto-approves its siblings and sends one grouped email' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:ticket) { { ticket: { payment_status: 'paid' } } }

        let!(:batch_id) { SecureRandom.uuid }
        let!(:primary) do
          create(
            :ticket,
            event: organizer_event,
            ticket_type: general_ticket_type,
            status: :pending_payment,
            payment_status: :pending,
            registration_batch_id: batch_id,
            attendee_email: 'batch-primary@example.com'
          )
        end
        let!(:sibling) do
          create(
            :ticket,
            event: organizer_event,
            ticket_type: general_ticket_type,
            status: :pending_payment,
            payment_status: :pending,
            registration_batch_id: batch_id,
            attendee_email: 'batch-sibling@example.com'
          )
        end
        let(:id) { primary.public_id }

        before { allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later) }

        schema TICKET_SCHEMA

        run_test! do
          expect(primary.reload.payment_status).to eq('paid')
          expect(sibling.reload.payment_status).to eq('paid')
          expect(sibling.reload.status).to eq('purchased')
          expect(EmailDelivery::AuditedDelivery).to have_received(:deliver_later).with(
            hash_including(mailer_action: 'group_confirmation_email')
          ).once
          expect(EmailDelivery::AuditedDelivery).not_to have_received(:deliver_later).with(
            hash_including(mailer_action: 'confirmation_email')
          )
        end
      end

      response '200', 'Ticket successfully updated by Org Owner' do
        let(:Authorization) { "Bearer #{org_owner_token}" }

        schema TICKET_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['attendee_name']).to eq('Updated Name')
        end
      end

      response '200', 'Ticket successfully updated by Organizer' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        schema TICKET_SCHEMA

        run_test!
      end

      response '403', 'Forbidden for unauthorized user' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end

    # ---------------------------------------------------------------------
    # --- DELETE - Destroy (Cancel/Refund) ---
    # ---------------------------------------------------------------------
    delete 'Cancels/Deletes a ticket (Soft Delete)' do
      tags 'Tickets'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { organizer_event.id }
      let(:id) { checked_in_ticket.public_id }

      response '204', 'Ticket successfully canceled by Organizer' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        run_test!
      end

      response '403', 'Forbidden for event staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------
  # --- DELETE - Force Delete (Hard Delete) ---
  # ---------------------------------------------------------------------
  path '/v1/events/{event_id}/tickets/{id}/force_delete' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'

    delete 'Force deletes a ticket (Hard Delete)' do
      tags 'Tickets'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { organizer_event.id }
      let(:id) { checked_in_ticket.public_id }

      response '204', 'Ticket successfully force deleted by Organizer' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        run_test!
      end

      response '403', 'Forbidden for event staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------
  # --- PATCH - Cancel Ticket ---
  # ---------------------------------------------------------------------
  path '/v1/events/{event_id}/tickets/{id}/cancel_ticket' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'

    patch 'Cancels a ticket (sets status to canceled)' do
      tags 'Tickets'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { organizer_event.id }
      let(:id) { purchased_ticket.public_id }

      response '204', 'Ticket successfully canceled by Organizer' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        run_test!
      end

      response '403', 'Forbidden for event staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------
  # --- PATCH - Restore Ticket ---
  # ---------------------------------------------------------------------
  path '/v1/events/{event_id}/tickets/{id}/restore' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'

    patch 'Restores an archived ticket' do
      tags 'Tickets'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { organizer_event.id }
      let(:id) { purchased_ticket.public_id }

      response '200', 'Ticket successfully restored by Organizer' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          purchased_ticket.archive
        end

        schema TICKET_SCHEMA
        run_test!
      end

      response '403', 'Forbidden for event staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # ---------------------------------------------------------------------
  # --- PATCH - Accept Waiting List Ticket ---
  # ---------------------------------------------------------------------
  path '/v1/events/{event_id}/tickets/{id}/accept_waiting_list' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'

    let!(:waiting_list_ticket) do
      create(
        :ticket,
        event: organizer_event,
        ticket_type: general_ticket_type,
        status: :pending_payment,
        payment_status: :pending,
        waiting_list: true,
        attendee_name: 'Waiting List Attendee'
      )
    end

    patch 'Accepts a waiting-list ticket, moving it to a purchased seat' do
      tags 'Tickets'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { organizer_event.id }
      let(:id) { waiting_list_ticket.public_id }

      response '200', 'Ticket successfully accepted off the waiting list' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do
          waiting_list_ticket.reload
          expect(waiting_list_ticket.waiting_list).to eq(false)
          expect(waiting_list_ticket.status).to eq('purchased')
          expect(waiting_list_ticket.payment_status).to eq('paid')
        end
      end

      response '403', 'Forbidden for an unassigned member' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end

      response '422', 'Ticket is not on the waiting list' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { purchased_ticket.public_id }
        run_test!
      end

      response '422', 'No seats available for the ticket type' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          general_ticket_type.update!(quantity: 1)
          purchased_ticket.update!(payment_status: :paid)
        end

        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # =========================================================================
  # Custom Route: /v1/tickets/:public_id/check_in
  # =========================================================================

  path '/v1/tickets/{public_id}/check_in' do
    parameter name: :public_id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'

    # --- PATCH - Global Check-in ---
    patch 'Performs a global check-in using only the Ticket Public ID' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:public_id) { purchased_ticket.public_id }

      response '200', 'Check-in successful via global scan by staff' do
        let(:public_id) { paid_purchased_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" }

        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA

        run_test! do
          paid_purchased_ticket.reload
          expect(paid_purchased_ticket.checked_in).to be true
        end
      end

      response '422', 'Already checked in' do
        let(:public_id) { checked_in_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '403', 'Forbidden for unauthorized user (member or staff of another event)' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:public_id) { '00000000-0000-0000-0000-000000000000' }
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end
    end
  end

  # =========================================================================
  # Email Verification Requirement Tests
  # =========================================================================

  describe 'Email Verification Enforcement for Tickets' do
    let(:unverified_user) { create(:user, :unverified) }
    let(:unverified_token) { JwtService.generate_tokens(unverified_user)[:access_token] }

    context 'when unverified user tries to access tickets' do
      it 'returns 403 Forbidden for index' do
        get "/v1/events/#{organizer_event.id}/tickets", headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        # Email verification check happens before authorization
        expect(json['message']).to eq('Email verification required')
      end

      it 'returns 403 Forbidden for show' do
        get "/v1/events/#{organizer_event.id}/tickets/#{purchased_ticket.public_id}",
            headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        # Email verification check happens before authorization
        expect(json['message']).to eq('Email verification required')
      end
    end
  end

  # =========================================================================
  # TICKET EXPORTS ENDPOINTS
  # =========================================================================

  path '/v1/tickets/exports' do
    # POST - Create Export
    post 'Create new ticket export for an event' do
      tags 'Ticket Exports'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :event_id, in: :query, type: :integer, required: true,
                description: 'Event ID to export tickets for'

      response '201', 'Export created successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     type: { type: :string },
                     created_at: { type: :string },
                     event_id: { type: :integer }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']['event_id']).to eq(organizer_event.id)
        end
      end

      response '401', 'Unauthorized - Missing or invalid token' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { nil }
        let(:event_id) { organizer_event.id }

        run_test!
      end

      response '403', 'Forbidden - Not authorized to export tickets for this event' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { organizer_event.id }

        run_test!
      end

      response '404', 'Event not found' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { 999999 }

        run_test!
      end

      response '422', 'Unprocessable Entity - Missing event_id parameter' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { nil }

        run_test!
      end
    end

    # GET - List Exports
    get 'List all exports for an event' do
      tags 'Ticket Exports'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :event_id, in: :query, type: :integer, required: true,
                description: 'Event ID to list exports for'

      response '200', 'Returns list of exports' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   type: { type: :string },
                   created_at: { type: :string },
                   updated_at: { type: :string },
                   event: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       title: { type: :string }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { organizer_event.id }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
        end
      end

      response '401', 'Unauthorized - Missing or invalid token' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { nil }
        let(:event_id) { organizer_event.id }

        run_test!
      end

      response '403', 'Forbidden - Not authorized to view exports for this event' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { organizer_event.id }

        run_test!
      end

      response '422', 'Unprocessable Entity - Missing event_id parameter' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { nil }

        run_test!
      end
    end
  end

  path '/v1/tickets/exports/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Export log ID'

    # GET - Download Export File
    get 'Download a specific export file' do
      tags 'Ticket Exports'
      produces 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'Excel file downloaded successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) do
          # Create an export first
          result = TicketExcelService.export(organizer_event.id)
          result[:export_log].id
        end

        run_test! do |response|
          expect(response.content_type).to include('spreadsheet')
          expect(response.headers['Content-Disposition']).to include('attachment')
        end
      end

      response '401', 'Unauthorized - Missing or invalid token' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { nil }
        let(:id) { 1 }

        run_test!
      end

      response '403', 'Forbidden - Not authorized to download this export' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) do
          result = TicketExcelService.export(organizer_event.id)
          result[:export_log].id
        end

        run_test!
      end

      response '404', 'Export not found' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { 999999 }

        run_test!
      end
    end
  end

  describe 'PATCH /v1/tickets/:public_id/check_in with multiple scans' do
    let(:event) { create(:event, multiple_scans: true, multiple_scan_mode: :unlimited) }
    let(:ticket) { create(:ticket, :paid, event: event) }
    let(:admin) { create(:user, :org_owner) }
    let(:admin_token) { JwtService.generate_tokens(admin)[:access_token] }
    let(:headers) { { 'Authorization' => "Bearer #{admin_token}" } }

    before do
      create(:event_assignment, event: event, user: admin, role: :event_admin)
    end

    it 'allows a second scan and appends a log' do
      patch "/v1/tickets/#{ticket.public_id}/check_in", headers: headers
      expect(response).to have_http_status(:ok)

      patch "/v1/tickets/#{ticket.public_id}/check_in", headers: headers
      expect(response).to have_http_status(:ok)

      expect(ScanLog.for_scannable(ticket).count).to eq(2)
    end

    it 'returns blocked_by when the mode forbids the re-scan' do
      event.update!(multiple_scan_mode: :per_day)

      patch "/v1/tickets/#{ticket.public_id}/check_in", headers: headers
      patch "/v1/tickets/#{ticket.public_id}/check_in", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['blocked_by']).to include('scanned_at')
      expect(ScanLog.for_scannable(ticket).count).to eq(1)
    end

    it 'still blocks the second scan when the toggle is off' do
      event.update!(multiple_scans: false)

      patch "/v1/tickets/#{ticket.public_id}/check_in", headers: headers
      patch "/v1/tickets/#{ticket.public_id}/check_in", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(ScanLog.for_scannable(ticket).count).to eq(1)
    end
  end

  describe 'POST /v1/tickets/self_check_in with multiple scans' do
    let(:event) { create(:event, multiple_scans: true, multiple_scan_mode: :unlimited) }
    let(:ticket) { create(:ticket, :paid, event: event) }

    it 'allows a repeat self check-in and records the source' do
      post '/v1/tickets/self_check_in', params: { public_id: ticket.public_id }
      expect(response).to have_http_status(:ok)

      post '/v1/tickets/self_check_in', params: { public_id: ticket.public_id }
      expect(response).to have_http_status(:ok)

      logs = ScanLog.for_scannable(ticket)
      expect(logs.count).to eq(2)
      expect(logs.pluck(:source).uniq).to eq(['self_check_in'])
      expect(ticket.reload.scanned_by_id).to be_nil
    end

    it 'blocks a repeat when the toggle is off' do
      event.update!(multiple_scans: false)

      post '/v1/tickets/self_check_in', params: { public_id: ticket.public_id }
      post '/v1/tickets/self_check_in', params: { public_id: ticket.public_id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ScanLog.for_scannable(ticket).count).to eq(1)
    end
  end

  describe 'PATCH /v1/tickets/:id/unscan with scan history' do
    let(:event) { create(:event, multiple_scans: true, multiple_scan_mode: :unlimited) }
    let(:ticket) { create(:ticket, :paid, event: event) }
    let(:owner) { create(:user, :org_owner) }
    let(:owner_token) { JwtService.generate_tokens(owner)[:access_token] }
    let(:headers) { { 'Authorization' => "Bearer #{owner_token}" } }

    it 'walks back one scan at a time' do
      ScanGate.record!(ticket, by: owner, at: 2.hours.ago)
      ScanGate.record!(ticket, by: owner, at: 1.hour.ago)

      patch "/v1/tickets/#{ticket.id}/unscan", headers: headers
      expect(response).to have_http_status(:ok)

      ticket.reload
      expect(ScanLog.for_scannable(ticket).count).to eq(1)
      expect(ticket.checked_in).to be true
      expect(ticket.status).to eq('scanned')
    end

    it 'fully resets once the last scan is removed' do
      ScanGate.record!(ticket, by: owner)

      patch "/v1/tickets/#{ticket.id}/unscan", headers: headers

      ticket.reload
      expect(ScanLog.for_scannable(ticket)).to be_empty
      expect(ticket.checked_in).to be false
      expect(ticket.check_in_at).to be_nil
      expect(ticket.status).to eq('purchased')
    end
  end
end
