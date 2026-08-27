module V1
  class TicketsController < ApplicationController
    include PublicFileValidation
    include ScannableCheckIn

    MAX_PAYMENT_PROOF_SIZE = 10.megabytes

    # Load and Authorize the parent event before every action
    before_action :set_event_and_authorize, except: [:global_check_in, :export, :self_check_in, :find_by_contact, :unscan]

    # Load the specific ticket for actions that require it
    before_action :set_ticket, only: [:show, :update, :destroy, :force_delete, :cancel_ticket, :restore, :resend_confirmation_email, :accept_waiting_list]

    # Skip authentication for public endpoints
    skip_before_action :authenticate_user!, only: [:self_check_in, :find_by_contact]

    # GET /v1/events/:event_id/tickets
    # Query params:
    #   - archived=true: Show only archived (soft-deleted) tickets
    #   - full=true: Show all tickets including archived ones
    #   - updated_since: ISO8601 timestamp. Returns only tickets updated at or
    #     after the given time. Use for incremental sync.
    #   - page / per_page: Paginate results. When either is present, the response
    #     is sliced and pagination metadata is returned via response headers
    #     (X-Total-Count, X-Page, X-Per-Page, X-Total-Pages). Root JSON shape
    #     remains a bare array for backwards compatibility.
    def index
      @tickets = policy_scope(Ticket).where(event: @event).includes(:ticket_type, :scanned_by, :pass_bundle, vehicle_registration: :registration_form, registration_documents_attachments: :blob)

      if params[:archived] == 'true'
        @tickets = @tickets.only_deleted
      elsif params[:full] == 'true'
        @tickets = @tickets.with_deleted
      end

      @tickets = @tickets.unassigned if params[:unassigned] == 'true'

      if params[:updated_since].present?
        begin
          since = Time.iso8601(params[:updated_since].to_s)
        rescue ArgumentError
          return render json: {
            error: 'invalid_updated_since',
            message: '`updated_since` must be a valid ISO8601 timestamp (e.g. 2026-05-18T00:00:00Z).'
          }, status: :bad_request
        end
        @tickets = @tickets.where('tickets.updated_at >= ?', since)
      end

      json_options = {
        methods: [:payment_method, :transaction_id, :payment_screenshot_url, :registration_documents_data, :vehicle_registration_data],
        include: {
          ticket_type: { only: [:id, :name, :price] },
          scanned_by: { only: [:id, :full_name] },
          pass_bundle: { only: [:id, :name] },
          ticket_application: {
            only: %i[review_status rsvp_status reviewed_at rejection_reason rsvp_sent_at rsvp_confirmed_at rsvp_expires_at]
          }
        }
      }

      if params[:page].present? || params[:per_page].present?
        ordered_scope = @tickets.reorder(id: :asc)
        pagy_obj, paginated = pagy(ordered_scope, limit: pagination_params[:per_page])

        response.headers['X-Total-Count'] = pagy_obj.count.to_s
        response.headers['X-Page']        = pagy_obj.page.to_s
        response.headers['X-Per-Page']    = pagy_obj.limit.to_s
        response.headers['X-Total-Pages'] = pagy_obj.pages.to_s

        render json: paginated.as_json(json_options), status: :ok
      else
        render json: @tickets.as_json(json_options), status: :ok
      end
    end

    # GET /v1/events/:event_id/tickets/:id
    def show
      # Authorize the specific ticket record against the show? policy
      authorize @ticket
      render json: ticket_response(@ticket), status: :ok
    end

    # POST /v1/events/:event_id/tickets
    def create
      # Authorization check
      authorize @event, :create_ticket?

      quantity = params[:quantity].to_i
      quantity = 1 if quantity < 1

      if quantity > 1 && !@event.allow_multiple_tickets_per_email?
        return render json: {
          errors: ['Multiple tickets per email is not enabled for this event']
        }, status: :unprocessable_content
      end

      # Build the ticket using ONLY the strong parameters.
      attrs = ticket_params_with_payment_sync
      payment_proof_file = attrs.delete(:payment_proof)
      return if payment_proof_file.present? && !valid_payment_proof!(payment_proof_file)

      @ticket = @event.tickets.build(attrs)

      # @ticket.user = current_user # Hide this for now

      # KEEP THIS LINE: Explicitly assign event_id to prevent the mysterious "must exist" error
      # seen in the test environment, even if @event.tickets.build is supposed to do it.
      @ticket.event_id = @event.id

      extra_tickets = []

      saved = ActiveRecord::Base.transaction do
        # Bulk-add: same attendee info repeated across N tickets, tied by
        # batch id so payment approval and confirmation email treat them as
        # one purchase — mirrors the public group-registration flow. Suppress
        # each ticket's own confirmation email; one batched email fires below
        # instead once the whole batch is confirmed paid.
        @ticket.suppress_confirmation_email = true if quantity > 1
        raise ActiveRecord::Rollback unless @ticket.save

        @ticket.update_column(:registration_batch_id, @ticket.public_id) if quantity > 1

        (quantity - 1).times do
          extra = @event.tickets.new(attrs)
          extra.registration_batch_id = @ticket.registration_batch_id
          extra.suppress_confirmation_email = true
          raise ActiveRecord::Rollback unless extra.save

          extra_tickets << extra
        end

        true
      end

      if saved
        @ticket.reload
        attach_payment_proof!(@ticket, payment_proof_file) if payment_proof_file.present?

        if quantity > 1 && @ticket.paid? && @ticket.purchased? && @ticket.attendee_email.present?
          EmailDelivery::AuditedDelivery.deliver_later(
            mailer_name: 'TicketMailer',
            mailer_action: 'group_confirmation_email',
            args: [@ticket],
            related: @ticket,
            metadata: { source: 'panel_bulk_ticket_create', event_id: @event.id }
          )
        end

        render json: ticket_response(@ticket).merge(
          group_public_ids: [@ticket.public_id, *extra_tickets.map(&:public_id)]
        ), status: :created
      else
        render json: @ticket.errors, status: :unprocessable_content
      end
    end

    def update
      # Authorization check: Can the user (Organizer/Staff) update this ticket?
      authorize @ticket, :update?

      # Manual bank-transfer approval mirrors the online-gateway path
      # (PaymentsController#mark_tickets_paid!): approving one ticket in a
      # group registration_batch auto-approves its siblings too (safe now
      # that the batch id scopes to exactly this submission, not just
      # email+ticket_type) and sends one batched QR email instead of N.
      marking_paid = @ticket.pending_payment? && ticket_params[:payment_status].to_s.in?(%w[paid 1])
      siblings = marking_paid && @ticket.registration_batch_id.present? ? batch_siblings(@ticket) : Ticket.none
      @ticket.suppress_confirmation_email = true if siblings.exists?

      reverting_paid = @ticket.paid? && ticket_params[:payment_status].present? &&
                        !ticket_params[:payment_status].to_s.in?(%w[paid 1])
      if reverting_paid && @ticket.scanned?
        return render json: { error: 'Ticket already checked in, cannot revert payment status' },
                      status: :unprocessable_content
      end
      if reverting_paid && @ticket.ticket_application&.approved?
        return render json: { error: 'This ticket has an approved application — use "Revert to Pending" instead' },
                      status: :unprocessable_content
      end

      attrs = ticket_params_with_payment_sync
      payment_proof_file = attrs.delete(:payment_proof)
      return if payment_proof_file.present? && !valid_payment_proof!(payment_proof_file)

      if @ticket.update(attrs)
        attach_payment_proof!(@ticket, payment_proof_file) if payment_proof_file.present?
        mark_batch_siblings_paid!(primary: @ticket, siblings: siblings) if siblings.exists?
        render json: ticket_response(@ticket), status: :ok
      else
        render json: @ticket.errors, status: :unprocessable_content
      end
    rescue VehicleRegistrationTicketTypeSync::Error => e
      render json: { errors: [e.message] }, status: :unprocessable_content
    end

    def accept_waiting_list
      authorize @ticket, :update?

      unless @ticket.waiting_list?
        return render json: { error: 'Ticket is not on the waiting list' }, status: :unprocessable_content
      end

      @ticket.ticket_type.with_lock do
        ticket_type = @ticket.ticket_type
        if ticket_type.quantity.present? && ticket_type.tickets
          .where(payment_status: :paid, status: %i[purchased scanned])
          .where.not(id: @ticket.id)
          .count >= ticket_type.quantity
          return render json: { error: 'No seats are currently available for this ticket type' }, status: :unprocessable_content
        end

        unless @ticket.update(waiting_list: false, payment_status: :paid, status: :purchased)
          return render json: @ticket.errors, status: :unprocessable_content
        end
      end

      render json: ticket_response(@ticket), status: :ok
    end

    def destroy
      # Authorization check: Can the user (Organizer/Admin) archive this ticket?
      authorize @ticket, :destroy?

      if @ticket.archive
        head :no_content
      else
        render json: @ticket.errors, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/tickets/:id/force_delete
    def force_delete
      # Authorization check: Can the user (Organizer/Admin) force delete this ticket?
      authorize @ticket, :force_delete?
      @ticket.delete
      head :no_content
    end

    # PATCH /v1/events/:event_id/tickets/:id/cancel_ticket
    def cancel_ticket
      # Authorization check: Can the user (Organizer/Admin) cancel this ticket?
      authorize @ticket, :cancel_ticket?

      if @ticket.update(status: :canceled)
        head :no_content
      else
        render json: @ticket.errors, status: :unprocessable_content
      end
    end

    # PATCH /v1/events/:event_id/tickets/:id/restore
    def restore
      # Authorization check: Can the user (Organizer/Admin) restore this ticket?
      authorize @ticket, :restore?

      if @ticket.restore
        render json: ticket_response(@ticket), status: :ok
      else
        render json: @ticket.errors, status: :unprocessable_content
      end
    end

    # POST /v1/events/:event_id/tickets/:id/resend_confirmation_email
    # Org owner only - resend ticket confirmation email with QR
    def resend_confirmation_email
      authorize @ticket, :resend_confirmation_email?

      if @ticket.attendee_email.blank?
        return render json: { errors: ['Ticket does not have an attendee email'] }, status: :unprocessable_content
      end

      if @ticket.waiting_list?
        return render json: { errors: ['Ticket is on the waiting list and has not been confirmed'] }, status: :unprocessable_content
      end

      # Resend the batched email (all QR codes) when this ticket belongs to a
      # paid group registration_batch — otherwise the admin's resend would
      # only cover this one attendee, dropping the others from the resend.
      batched = @ticket.paid? && @ticket.registration_batch_id.present? &&
        @event.tickets.where(registration_batch_id: @ticket.registration_batch_id, payment_status: :paid).count > 1

      delivery = EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: batched ? 'group_confirmation_email' : 'confirmation_email',
        args: [@ticket],
        related: @ticket,
        metadata: {
          source: 'ticket_actions_menu_manual_resend',
          event_id: @event.id
        }
      )

      render json: {
        message: 'Ticket confirmation email has been queued for resend',
        email_delivery_id: delivery.id
      }, status: :accepted
    end

    def global_check_in
      @ticket = Ticket.find_by!(public_id: params[:public_id])
      authorize @ticket, :check_in?

      status, log = ScanGate.record!(
        @ticket,
        by: current_user,
        source: :staff_scan,
        location: scan_location_for(@ticket.event)
      )

      if status == :blocked
        render json: scan_blocked_payload(log, message: 'Ticket has already been checked in.'),
               status: :unprocessable_content and return
      end

      broadcast_to_welcome_screen(@ticket)
      render json: @ticket.reload.as_json(include: {
        ticket_type: { only: %i[id name price] },
        event: { only: %i[id title] }
      }), status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Ticket not found' }, status: :not_found
    end

    # GET /v1/tickets/export?event_id=1
    def export
      # Authorization: User must be authenticated
      unless current_user
        return render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      # Validate event_id parameter
      unless params[:event_id].present?
        return render json: { error: 'event_id parameter is required' }, status: :unprocessable_content
      end

      begin
        event = Event.find(params[:event_id])

        # Authorization: User must have access to this event
        authorize event, :show?

        result = TicketExcelService.export(params[:event_id])

        # Send the file to the client
        send_file(
          result[:file_path],
          filename: File.basename(result[:file_path]),
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          disposition: 'attachment'
        )
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Event not found' }, status: :not_found
      rescue Pundit::NotAuthorizedError
        render json: { error: 'Not authorized to export tickets for this event' }, status: :forbidden
      rescue StandardError => e
        Rails.logger.error "Ticket export error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        error_response(
          message: 'Export failed',
          errors: [e.message],
          status: :unprocessable_content
        )
      end
    end

    # POST /v1/tickets/find_by_contact
    # Public endpoint - find ticket by email, phone, or name (no authentication required)
    def find_by_contact
      attendee_email = params[:attendee_email]
      attendee_phone = params[:attendee_phone]
      attendee_name = params[:attendee_name]

      if attendee_email.blank? && attendee_phone.blank? && attendee_name.blank?
        render json: { error: 'Either email, phone number, or name is required' }, status: :bad_request and return
      end

      query = Ticket.where(payment_status: 'paid')
      conditions = []
      values = []

      if attendee_email.present?
        conditions << 'LOWER(attendee_email) = ?'
        values << attendee_email.strip.downcase
      end

      if attendee_phone.present?
        # Normalize the search phone number (remove all non-digits)
        normalized_phone = attendee_phone.gsub(/\D+/, '')
        conditions << 'attendee_phone_norm = ?'
        values << normalized_phone
      end

      if attendee_name.present?
        normalized_search = attendee_name.strip.downcase
        search_no_spaces = normalized_search.gsub(/\s+/, '')

        # Flexible name matching: exact, partial, with/without spaces, first/last name
        name_conditions = [
          'LOWER(attendee_name) = ?',
          'LOWER(attendee_name) LIKE ?',
          'REPLACE(LOWER(attendee_name), \' \' , \'\') = ?',
          'REPLACE(LOWER(attendee_name), \' \' , \'\') LIKE ?',
          'LOWER(attendee_name) LIKE ?',
          'LOWER(attendee_name) LIKE ?'
        ]

        conditions << "(#{name_conditions.join(' OR ')})"
        values.concat([
          normalized_search,
          "%#{normalized_search}%",
          search_no_spaces,
          "%#{search_no_spaces}%",
          "#{normalized_search}%",
          "% #{normalized_search}%"
        ])
      end

      # Name searches return all matches (max 10), email/phone return single ticket
      if attendee_name.present? && attendee_email.blank? && attendee_phone.blank?
        @tickets = query.where(conditions.join(' OR '), *values)
                       .order(created_at: :desc)
                       .limit(10)

        if @tickets.empty?
          render json: { error: 'No ticket found with the provided contact information' }, status: :not_found and return
        end

        render json: {
          multiple_matches: @tickets.count > 1,
          tickets: @tickets.as_json(
            include: {
              ticket_type: { only: [:id, :name, :price] },
              event: { only: [:id, :title] }
            }
          )
        }, status: :ok
      else
        @ticket = query.where(conditions.join(' OR '), *values)
                       .order(created_at: :desc)
                       .first

        if @ticket.nil?
          render json: { error: 'No ticket found with the provided contact information' }, status: :not_found and return
        end

        render json: @ticket.as_json(
          include: {
            ticket_type: { only: [:id, :name, :price] },
            event: { only: [:id, :title] }
          }
        ), status: :ok
      end
    rescue StandardError => e
      render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
    end

    # POST /v1/tickets/self_check_in
    # Public endpoint for attendees to check themselves in using ticket public_id
    # No authentication required, no scanned_by_id set
    # Optionally accepts attendee_phone, attendee_email, and check_in_url to update missing contact info
    def self_check_in
      public_id = params[:public_id]

      if public_id.blank?
        render json: { error: 'Ticket ID is required' }, status: :bad_request and return
      end

      @ticket = Ticket.find_by(public_id: public_id)

      if @ticket.nil?
        render json: { error: 'Ticket not found' }, status: :not_found and return
      end

      # Fill in contact details the attendee supplied, if we don't have them yet.
      contact_updates = {}
      if params[:attendee_phone].present? && @ticket.attendee_phone.blank?
        contact_updates[:attendee_phone] = params[:attendee_phone]
      end
      if params[:attendee_email].present? && @ticket.attendee_email.blank?
        contact_updates[:attendee_email] = params[:attendee_email]
      end
      @ticket.update!(contact_updates) if contact_updates.any?

      # The ticket.checked_in webhook reads this thread-local.
      Thread.current[:check_in_url] = params[:check_in_url] if params[:check_in_url].present?

      status, log = ScanGate.record!(@ticket, by: nil, source: :self_check_in)

      if status == :blocked
        render json: scan_blocked_payload(log, message: 'This ticket has already been checked in.'),
               status: :unprocessable_content and return
      end

      broadcast_to_welcome_screen(@ticket)
      render json: @ticket.reload.as_json(
        include: {
          ticket_type: { only: %i[id name price] },
          event: { only: %i[id title] }
        }
      ), status: :ok
    rescue StandardError => e
      render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
    ensure
      Thread.current[:check_in_url] = nil
    end

    # PATCH /v1/tickets/:id/unscan
    # Org owner only - unscan a ticket (reset check-in status)
    def unscan
      @ticket = Ticket.find_by(id: params[:id]) || Ticket.find_by!(public_id: params[:id])
      authorize @ticket, :unscan?

      unless ScanGate.undo!(@ticket)
        render json: { error: 'Ticket is not checked in' }, status: :unprocessable_content and return
      end

      render json: {
        message: 'Ticket successfully unscanned',
        ticket: @ticket.reload.as_json(
          methods: %i[payment_method transaction_id payment_screenshot_url],
          include: { ticket_type: { only: %i[id name price] } }
        )
      }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Ticket not found' }, status: :not_found
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Only organization owners and organizers can unscan tickets' }, status: :forbidden
    rescue StandardError => e
      render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
    end

    private

    def broadcast_to_welcome_screen(ticket)
      WelcomeScreenQueueService.enqueue(
        ticket.event_id,
        ticket.attendee_name,
        custom_fields_data: ticket.custom_fields_data
      )
    end

    def batch_siblings(ticket)
      @event.tickets.where(
        registration_batch_id: ticket.registration_batch_id,
        payment_status: %i[pending failed],
        status: :pending_payment
      ).where.not(id: ticket.id)
    end

    def mark_batch_siblings_paid!(primary:, siblings:)
      siblings.find_each do |sibling|
        sibling.suppress_confirmation_email = true
        sibling.update!(payment_status: :paid, status: :purchased)
      end

      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketMailer',
        mailer_action: 'group_confirmation_email',
        args: [primary],
        related: primary,
        metadata: { source: 'manual_payment_approval_batch', event_id: @event.id }
      )
    end

    def set_event
      # Allow accessing archived events for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    end

    # Refactored set_event and authorize into one method for clarity and correct execution order.
    # The Pundit check now uses the parent resource (@event) for authorization,
    # preventing the 403 test failure for unauthorized access.
    # Refactored set_event and authorize into one method for clarity and correct execution order.
    def set_event_and_authorize
      set_event
      if action_name != 'create'
         authorize @event, :show?
      end

    end

    def set_ticket
      # Prioritize finding by UUID (public_id) for security and external API use
      # For restore and force_delete actions, use unscoped to find soft-deleted tickets
      if action_name.in?(['restore', 'force_delete'])
        @ticket = @event.tickets.unscoped.where(event_id: @event.id).find_by!(public_id: params[:id])
      else
        @ticket = @event.tickets.find_by!(public_id: params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      # Fallback to internal ID if UUID fails (e.g., if staff uses the internal integer ID)
      render json: { error: 'Ticket not found' }, status: :not_found
    end

    def ticket_params
      # Fields allowed for creation and general attendee updates.
      allowed_params = [
        :attendee_name,
        :attendee_email,
        :attendee_phone,
        :ticket_type_id,
        :payment_status,
        :waiting_list,
        :payment_method,
        :transaction_id,
        :payment_screenshot_url,
        :payment_proof,
        :role,
        :skip_webhooks,
        custom_fields_data: {}
      ]

      # Add fields often needed for staff/organizer updates or specific actions,
      # but ensure the controller logic authorizes these updates (handled by Pundit).
      if action_name.in?(['update', 'destroy', 'global_check_in', 'self_check_in', 'unscan'])
        allowed_params << :checked_in
        allowed_params << :status
      end

      permitted = params.require(:ticket).permit(*allowed_params)

      # Reserved keys (e.g. _indemnity) are server-written audit records; even
      # admins must not overwrite them through this endpoint.
      if permitted[:custom_fields_data].present?
        permitted[:custom_fields_data] = permitted[:custom_fields_data].except(*Ticket::RESERVED_CUSTOM_FIELD_KEYS)
      end

      # multipart/form-data (used when payment_proof is uploaded) stringifies
      # every field, but Ticket#payment_status is an integer-backed enum and
      # rejects a digit string like "0" as an invalid key — only the bare
      # integer or its label ("pending") is accepted.
      if permitted[:payment_status].present? && permitted[:payment_status].to_s.match?(/\A\d+\z/)
        permitted[:payment_status] = permitted[:payment_status].to_i
      end

      permitted
    end

    def ticket_params_with_payment_sync
      permitted_params = ticket_params
      payment_status = permitted_params[:payment_status]

      return permitted_params unless payment_status.present?

      paid_value = Ticket.payment_statuses[:paid]
      going_paid = payment_status.to_s == 'paid' || payment_status.to_s == paid_value.to_s

      return permitted_params.merge(status: :purchased) if @ticket&.pending_payment? && going_paid

      # Reverting a paid, not-yet-scanned ticket back to an unpaid status also
      # resets its lifecycle status to pending_payment, mirroring the forward
      # sync above (organizer un-paying = same as reverting an approval).
      return permitted_params.merge(status: :pending_payment) if @ticket&.paid? && @ticket.purchased? && !going_paid

      permitted_params
    end

    # Renders an error and returns false when the uploaded payment proof
    # fails type/size checks (mirrors V1::Public::TicketPaymentProofsController).
    def valid_payment_proof!(file)
      unless file.respond_to?(:content_type) && allowed_file_type?(file)
        render json: { errors: ['Payment proof must be a JPEG, PNG, WebP, or PDF'] }, status: :unprocessable_content
        return false
      end

      if file_too_large?(file, MAX_PAYMENT_PROOF_SIZE)
        render json: { errors: ["Payment proof is too large (max #{MAX_PAYMENT_PROOF_SIZE / 1.megabyte}MB)"] },
               status: :unprocessable_content
        return false
      end

      true
    end

    # Attaches an admin-uploaded payment proof to the ticket's payment record
    # via Active Storage, replacing the legacy free-text payment_screenshot_url.
    def attach_payment_proof!(ticket, file)
      payment = ticket.payment_record
      # On a brand-new ticket (create action), payment_record builds an
      # unsaved TicketPayment — Active Storage can't attach to an unpersisted
      # record (no id to generate a signed_id from), so save it first.
      payment.save! if payment.new_record?
      payment.payment_proof.attach(file)
      payment.update!(payment_screenshot_url: url_for(payment.payment_proof))
    end

    def ticket_response(ticket)
      ticket.as_json(
        methods: [:payment_method, :transaction_id, :payment_screenshot_url, :registration_documents_data, :vehicle_registration_data],
        include: {
          ticket_type: { only: [:id, :name, :price] },
          pass_bundle: { only: [:id, :name] },
          ticket_application: {
            only: %i[review_status rsvp_status reviewed_at rejection_reason rsvp_sent_at rsvp_confirmed_at rsvp_expires_at]
          }
        }
      )
    end
  end
end
