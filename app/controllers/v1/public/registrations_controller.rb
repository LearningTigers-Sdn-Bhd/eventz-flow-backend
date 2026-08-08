# frozen_string_literal: true

module V1
  module Public
    class RegistrationsController < ApplicationController
      # Skip all authentication for public endpoints
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def registration_forms
        event = Event.friendly.find(params[:event_slug])
        forms = event.registration_forms.order(:position, :created_at)

        render json: {
          success: true,
          data: forms.map do |f|
            {
              slug: f.slug,
              name: f.name,
              description: f.description,
              status: RegistrationForm.statuses[f.status],
              custom_labels_data: f.custom_labels_data || []
            }
          end
        }
      end

      def registration_status
        event = Event.friendly.find(params[:event_slug])
        email = params[:email].to_s.strip.downcase
        form_slug = params[:form_slug].to_s.strip
        form = nil

        if email.blank?
          return render json: {
            success: false,
            message: 'Email is required'
          }, status: :unprocessable_content
        end

        tickets = event.tickets.where(
          'LOWER(attendee_email) = :email OR LOWER(registered_by_email) = :email',
          email: email
        )
        if form_slug.present?
          form = event.registration_forms.find_by(slug: form_slug)
          tickets = tickets.where(ticket_type_id: registration_status_ticket_type_ids(event:, form:)) if form
        end

        rejected_application = rejected_application_for_form(event:, form:, email:)

        upgrade_ticket = conference_upgrade_ticket(event:, email:, form_slug:)
        blocked_upgrade_ticket = blocked_conference_upgrade_ticket(event:, email:, form_slug:)

        pending_tickets = tickets
                          .where(status: :pending_payment, payment_status: %i[pending failed])
                          .includes(:ticket_type)
                          .order(created_at: :desc)

        paid_tickets = tickets
                       .where(payment_status: :paid)
                       .where.not(status: %i[canceled refunded])
                       .includes(:ticket_type)
                       .order(created_at: :desc)

        render json: {
          success: true,
          data: {
            has_pending_payment: pending_tickets.exists?,
            has_paid_ticket: paid_tickets.exists?,
            has_rejected_application: rejected_application.present?,
            rejected_message: rejected_application_message(event: event, rejected_application: rejected_application),
            pending_tickets: pending_tickets.limit(5).map do |ticket|
              serialize_status_ticket(ticket)
            end,
            paid_tickets: paid_tickets.limit(5).map do |ticket|
              serialize_status_ticket(ticket)
            end,
            upgrade_mode: upgrade_ticket.present?,
            upgrade_target: upgrade_ticket.present? ? 'conference' : nil,
            existing_ticket_public_id: upgrade_ticket&.public_id,
            existing_attendee_name: upgrade_ticket&.attendee_name,
            existing_attendee_email: upgrade_ticket&.attendee_email,
            existing_attendee_phone: upgrade_ticket&.attendee_phone,
            existing_ticket_type: upgrade_ticket&.ticket_type&.name,
            blocked_exhibitor_upgrade: blocked_upgrade_ticket.present?,
            blocked_reason: blocked_upgrade_ticket.present? ? 'unpaid_exhibitor' : nil,
            blocked_message: blocked_upgrade_ticket.present? ? 'You already have an unpaid exhibitor registration. Please complete that payment first before registering for conference.' : nil
          }
        }
      end

      def pass_bundle
        event = Event.friendly.find(params[:event_slug])
        bundle = event.pass_bundles.includes(:registration_form, :ticket_type).find_by(token: params[:token].to_s.strip)

        unless bundle
          return render json: {
            success: false,
            message: 'Invalid or expired bundle link.'
          }, status: :not_found
        end

        if bundle.expired?
          return render json: {
            success: false,
            message: 'Invalid or expired bundle link.'
          }, status: :unprocessable_content
        end

        if bundle.paused?
          return render json: {
            success: false,
            message: 'This bundle is paused. Please contact the organizer.'
          }, status: :unprocessable_content
        end

        if bundle.full?
          return render json: {
            success: false,
            message: 'This bundle is full. Please contact the organizer.'
          }, status: :unprocessable_content
        end

        render json: {
          success: true,
          data: {
            name: bundle.name,
            token: bundle.token,
            pass_limit: bundle.pass_limit,
            used_count: bundle.used_count,
            remaining_count: bundle.remaining_count,
            payment_mode: bundle.payment_mode,
            payment_status: bundle.payment_status,
            registration_form: {
              name: bundle.registration_form.name,
              slug: bundle.registration_form.slug
            },
            ticket_type: {
              id: bundle.ticket_type.id,
              name: bundle.ticket_type.name
            }
          }
        }
      end

      # Pre-submit duplicate check for uniquely-constrained custom fields.
      # The key allowlist stops this becoming an unauthenticated read oracle
      # over arbitrary jsonb.
      def field_availability
        event = Event.friendly.find(params[:event_slug])

        key = params[:key].to_s
        unless Ticket::UNIQUE_CUSTOM_FIELD_KEYS.include?(key)
          return render json: { success: false, message: 'Unsupported field key' }, status: :unprocessable_content
        end

        value = params[:value].to_s.strip
        if value.blank?
          return render json: { success: false, message: 'Value is required' }, status: :unprocessable_content
        end

        taken = event.tickets
                     .where.not(status: :canceled)
                     .where('lower(custom_fields_data->>?) = ?', key, value.downcase)
                     .exists?

        render json: {
          success: true,
          data: { key: key, value: value, available: !taken }
        }
      end

      def vehicle_registration
        event = Event.friendly.find(params[:event_slug])
        form = event.registration_forms.active.find_by(slug: params[:form_slug])
        return render json: { success: false, message: 'Registration form not found' }, status: :not_found unless form

        plate = VehicleRegistration.normalize_plate(params[:plate])
        if plate.blank?
          return render json: { success: false, message: 'Car plate number is required' },
                        status: :unprocessable_content
        end

        rules = VehicleRegistrationRules.new(form)
        vehicle = VehicleRegistration.includes(:registration_form, :base_ticket_type)
                                     .find_by(event: event, normalized_plate: plate)
        vehicle ||= VehicleRegistrationLegacyAdopter.call(event: event, normalized_plate: plate)

        if vehicle && vehicle.registration_form_id != form.id
          return render json: {
            success: true,
            data: {
              status: 'wrong_form',
              plate: plate,
              occupancy: vehicle.active_tickets.count,
              capacity: VehicleRegistrationRules.new(vehicle.registration_form).capacity,
              registered_form_slug: vehicle.registration_form.slug,
              registered_form_name: vehicle.registration_form.name,
              allowed_ticket_type_ids: []
            }
          }
        end

        render json: {
          success: true,
          data: {
            status: rules.status(vehicle),
            plate: plate,
            occupancy: vehicle&.active_tickets&.count || 0,
            capacity: rules.capacity,
            registered_form_slug: vehicle&.registration_form&.slug,
            registered_form_name: vehicle&.registration_form&.name,
            allowed_ticket_type_ids: rules.allowed_ticket_types(vehicle).pluck(:id),
            registered_roles: vehicle&.active_tickets&.pluck(:role) || []
          }
        }
      rescue VehicleRegistrationRules::UnsupportedForm => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def create
        event = Event.friendly.find(params[:event_slug])
        form = nil

        unless event.published?
          return render json: {
            success: false,
            message: 'Registration is not open for this event'
          }, status: :unprocessable_content
        end

        available_ticket_types = event.ticket_types.publicly_available

        # Filter by form_slug if provided
        if params[:form_slug].present?
          form = event.registration_forms.find_by(slug: params[:form_slug])
          unless form
            return render json: {
              success: false,
              message: 'Registration form not found'
            }, status: :not_found
          end

          if form.closed?
            return render json: {
              success: false,
              message: 'Registration is closed for this form'
            }, status: :unprocessable_content
          end

          allowed_ticket_type_ids = form.ticket_type_ids
          unless allowed_ticket_type_ids.include?(params[:ticket_type_id].to_i)
            return render json: {
              success: false,
              message: 'Ticket type is not allowed for the selected registration form'
            }, status: :unprocessable_content
          end

          available_ticket_types = available_ticket_types.where(id: allowed_ticket_type_ids)
        end

        ticket_type = available_ticket_types.find(params[:ticket_type_id])
        unless ticket_type.available_for_purchase?
          return render json: {
            success: false,
            code: 'ticket_sold_out',
            message: 'This ticket type is sold out'
          }, status: :unprocessable_content
        end

        if form.nil? && vehicle_registration_ticket_type?(event: event, ticket_type: ticket_type)
          return render json: {
            success: false,
            message: 'Registration form is required for this vehicle ticket'
          }, status: :unprocessable_content
        end

        bundle = resolve_pass_bundle(event:, form:, ticket_type:)
        return if performed?
        approval_enabled = delegate_approval_enabled_for_form?(form)
        normalized_attendee_email = registration_params[:attendee_email].to_s.strip.downcase

        if approval_enabled && rejected_application_for_form(event:, form:, email: normalized_attendee_email).present?
          return render json: {
            success: false,
            message: 'Your application was not selected in this intake. Thank you for your interest.'
          }, status: :unprocessable_content
        end

        if (terms_error = terms_agreement_error(form: form))
          return render json: {
            success: false,
            errors: [terms_error]
          }, status: :unprocessable_content
        end

        if (documents_error = required_documents_error(form: form))
          return render json: {
            success: false,
            errors: [documents_error]
          }, status: :unprocessable_content
        end

        ticket = conference_upgrade_ticket(
          event: event,
          email: registration_params[:attendee_email],
          form_slug: params[:form_slug]
        )

        if ticket
          return render json: {
            success: true,
            data: serialize_ticket(ticket, ticket_type)
          }, status: :created
        else
          ticket = event.tickets.new(registration_params)
          ticket.ticket_type = ticket_type
          ticket.pass_bundle = bundle if bundle.present?
          ticket.waiting_list = form&.waiting_list? || false

          if ticket.waiting_list || approval_enabled
            ticket.status = 'pending_payment'
            ticket.payment_status = 'pending'
          elsif bundle.present?
            apply_bundle_payment_state!(ticket: ticket, bundle: bundle)
          elsif auto_paid_ticket?(event: event, ticket: ticket, ticket_type: ticket_type)
            ticket.status = 'purchased'
            ticket.payment_status = 'paid'
          else
            ticket.status = 'pending_payment'
            ticket.payment_status = 'pending'
          end
        end

        apply_indemnity!(ticket)
        apply_terms_agreement!(ticket, form: form)

        begin
          RegistrationDocumentAttacher.new(event: event, ticket: ticket, documents: params[:documents] || {}).call
        rescue RegistrationDocumentAttacher::Error => e
          return render json: { success: false, message: e.message }, status: :unprocessable_content
        end

        begin
          saved = if VehicleRegistrationRules.supported?(form)
                    VehicleRegistrationAssignment.new(
                      event: event,
                      form: form,
                      ticket: ticket,
                      plate: params[:vehicle_plate]
                    ).save
                  else
                    ticket.save
                  end
        rescue VehicleRegistrationAssignment::Error => e
          return render json: {
            success: false,
            code: 'vehicle_registration_conflict',
            message: e.message
          }, status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          # The model validation races under concurrent submits; the partial
          # unique index does not. Same message either way.
          return render json: {
            success: false,
            errors: ['This membership or IC/passport number is already registered for this event']
          }, status: :unprocessable_content
        end

        if saved
          handle_ticket_application!(registration_form: form, ticket: ticket)
          send_payment_pending_notification(ticket)

          render json: {
            success: true,
            data: serialize_ticket(ticket, ticket.ticket_type)
          }, status: :created
        else
          render json: {
            success: false,
            errors: ticket.errors.full_messages
          }, status: :unprocessable_content
        end
      end

      def ticket_types
        event = Event.friendly.find(params[:event_slug])

        available_ticket_types = event.ticket_types.publicly_available
        rule_by_ticket_type_id = {}

        # Filter by form_slug if provided
        if params[:form_slug].present?
          form = event.registration_forms.find_by(slug: params[:form_slug])
          unless form
            return render json: {
              success: false,
              message: 'Registration form not found'
            }, status: :not_found
          end

          mappings = form.registration_form_ticket_types
                         .where(ticket_type_id: available_ticket_types.select(:id))

          rule_by_ticket_type_id = mappings.index_by(&:ticket_type_id)
          available_ticket_types = available_ticket_types.where(id: rule_by_ticket_type_id.keys)
        end

        ticket_types = available_ticket_types.map do |tt|
          rule = rule_by_ticket_type_id[tt.id]

          {
            id: tt.id,
            name: tt.name,
            price: tt.current_price,
            original_price: tt.price,
            current_tier: tt.active_tier&.label,
            available: tt.available_for_purchase?,
            remaining_slots: tt.remaining_quantity,
            custom_fields_data: tt.custom_fields_data,
            custom_labels_data: rule&.custom_labels_data || [],
            registration_mode: rule&.registration_mode || 'single',
            min_attendees: rule&.min_attendees || 1,
            max_attendees: rule&.max_attendees
          }
        end

        render json: { success: true, data: ticket_types }
      end

      private

      def vehicle_registration_ticket_type?(event:, ticket_type:)
        forms = event.registration_forms
                     .joins(:registration_form_ticket_types)
                     .where(registration_form_ticket_types: { ticket_type_id: ticket_type.id })
        forms.any? { |form| VehicleRegistrationRules.supported?(form) }
      end

      def registration_params
        permitted = params.permit(
          :attendee_name,
          :attendee_email,
          :attendee_phone,
          :role,
          :registered_by_email,
          custom_fields_data: {}
        )

        # Reserved keys are server-written; a client must not forge them.
        if permitted[:custom_fields_data].present?
          permitted[:custom_fields_data] = permitted[:custom_fields_data].except(*Ticket::RESERVED_CUSTOM_FIELD_KEYS)
        end

        permitted
      end

      def indemnity_params
        params.fetch(:indemnity, {}).permit(:accepted, :method, :signed_name)
      end

      def terms_agreement_params
        terms = params[:terms_agreement]
        return ActionController::Parameters.new unless terms.respond_to?(:permit)

        terms.permit(
          :accepted,
          :method,
          :acknowledged_name,
          :terms_version
        )
      end

      def terms_agreement_error(form:)
        vehicle_form = vehicle_registration_form?(form)
        if params[:terms_agreement].blank?
          return vehicle_form ? 'Registration terms must be accepted' : nil
        end

        agreement = terms_agreement_params
        return 'Registration terms must be accepted' unless ActiveModel::Type::Boolean.new.cast(agreement[:accepted])
        return 'A full legal name is required for the terms acknowledgement' if agreement[:acknowledged_name].to_s.strip.blank?
        return 'Registration terms version is required' if agreement[:terms_version].to_s.strip.blank?
        if vehicle_form && agreement[:method].to_s != VehicleRegistrationRules::TERMS_METHOD
          return 'A typed-name terms acknowledgement is required'
        end
        if vehicle_form && agreement[:terms_version].to_s.strip != VehicleRegistrationRules::TERMS_VERSION
          return 'This registration uses an outdated terms version'
        end

        nil
      end

      def required_documents_error(form:)
        return unless vehicle_registration_form?(form)

        provided_keys = params[:documents].respond_to?(:keys) ? params[:documents].keys.map(&:to_s) : []
        missing_keys = VehicleRegistrationRules::REQUIRED_DOCUMENT_KEYS - provided_keys
        return if missing_keys.empty?

        "Registration requires these documents: #{missing_keys.join(', ')}"
      end

      def vehicle_registration_form?(form)
        VehicleRegistrationRules.supported?(form)
      end

      def apply_indemnity!(ticket)
        return unless ActiveModel::Type::Boolean.new.cast(indemnity_params[:accepted])

        ticket.custom_fields_data = (ticket.custom_fields_data || {}).merge(
          '_indemnity' => {
            'accepted' => true,
            'method' => indemnity_params[:method].to_s.presence,
            'signed_name' => indemnity_params[:signed_name].to_s.presence,
            'signed_at' => Time.current.utc.iso8601 # server clock, never client-supplied
          }.compact
        )
      end

      def apply_terms_agreement!(ticket, form:)
        return unless ActiveModel::Type::Boolean.new.cast(terms_agreement_params[:accepted])

        vehicle_form = vehicle_registration_form?(form)

        ticket.custom_fields_data = (ticket.custom_fields_data || {}).merge(
          '_terms_agreement' => {
            'accepted' => true,
            'method' => vehicle_form ? VehicleRegistrationRules::TERMS_METHOD : terms_agreement_params[:method].to_s.presence,
            'acknowledged_name' => terms_agreement_params[:acknowledged_name].to_s.strip.presence,
            'terms_version' => vehicle_form ? VehicleRegistrationRules::TERMS_VERSION : terms_agreement_params[:terms_version].to_s.strip.presence,
            'accepted_at' => Time.current.utc.iso8601 # server clock, never client-supplied
          }.compact
        )
      end

      def serialize_ticket(ticket, ticket_type)
        {
          ticket_id: ticket.id,
          public_id: ticket.public_id,
          attendee_name: ticket.attendee_name,
          attendee_email: ticket.attendee_email,
          attendee_phone: ticket.attendee_phone,
          role: ticket.role,
          ticket_type: ticket_type.name,
          price: ticket_type.current_price,
          payment_status: ticket.payment_status,
          waiting_list: ticket.waiting_list,
          custom_fields_data: ticket.custom_fields_data,
          qr_code_data: ticket.public_id,
          documents: serialize_documents(ticket)
        }
      end

      def serialize_documents(ticket)
        return [] unless ticket.persisted?

        ticket.registration_documents.map do |attachment|
          {
            key: attachment.blob.metadata['document_key'],
            filename: attachment.blob.filename.to_s,
            url: url_for(attachment)
          }
        end
      end

      def serialize_status_ticket(ticket)
        {
          id: ticket.id,
          public_id: ticket.public_id,
          attendee_name: ticket.attendee_name,
          attendee_email: ticket.attendee_email,
          registered_by_email: ticket.registered_by_email,
          attendee_phone: ticket.attendee_phone,
          ticket_type: ticket.ticket_type&.name,
          ticket_type_id: ticket.ticket_type_id,
          price: ticket.ticket_type&.current_price || 0,
          payment_status: ticket.payment_status,
          status: ticket.status,
          waiting_list: ticket.waiting_list,
          created_at: ticket.created_at,
          custom_fields_data: ticket.custom_fields_data || {},
          qr_code_data: ticket.public_id
        }
      end

      def handle_ticket_application!(registration_form:, ticket:)
        return if registration_form.blank?

        setting = registration_form.registration_form_rsvp_setting
        return unless setting&.enabled?

        application = ticket.ticket_application || ticket.create_ticket_application!(
          registration_form: registration_form,
          review_status: :pending_review,
          rsvp_status: :not_sent
        )

        if ticket.attendee_email.present?
          EmailDelivery::AuditedDelivery.deliver_later(
            mailer_name: 'TicketApplicationMailer',
            mailer_action: 'acknowledgement',
            args: [application],
            related: application
          )
        end
      end

      # One email per ticket covering "payment pending" regardless of whether
      # proof is uploaded now or later — avoids a second send at upload time
      # (spam risk). Skipped for waitlist/approval flows (they already get
      # TicketApplicationMailer#acknowledgement) and exhibitor ticket types.
      def send_payment_pending_notification(ticket)
        return if ticket.paid? || ticket.waiting_list || ticket.ticket_application.present?
        return if ticket.exhibitor_ticket_type? || ticket.attendee_email.blank?

        EmailDelivery::AuditedDelivery.deliver_later(
          mailer_name: 'TicketMailer',
          mailer_action: 'payment_pending_email',
          args: [ticket],
          related: ticket,
          dedupe: true
        )
      end

      def delegate_approval_enabled_for_form?(form)
        return false unless form

        form.registration_form_rsvp_setting&.enabled? || false
      end

      def rejected_application_for_form(event:, form:, email:)
        return nil if form.blank? || email.blank?

        TicketApplication
          .joins(:ticket)
          .where(
            registration_form_id: form.id,
            review_status: TicketApplication.review_statuses[:rejected],
            tickets: { event_id: event.id }
          )
          .where('tickets.attendee_email_norm = :email OR LOWER(tickets.attendee_email) = :email', email: email)
          .order(reviewed_at: :desc, id: :desc)
          .first
      end

      def rejected_application_message(event:, rejected_application:)
        return nil unless rejected_application

        'Your application was not selected in this intake. Thank you for your interest.'
      end

      def registration_status_ticket_type_ids(event:, form:)
        ticket_type_ids = form.ticket_type_ids

        return ticket_type_ids unless borneo_conference_form?(event:, form:)

        ticket_type_ids + borneo_combined_ticket_type_ids(event) + borneo_exhibitor_only_ticket_type_ids(event)
      end

      def conference_upgrade_ticket(event:, email:, form_slug:)
        conference_upgrade_source_ticket(
          event: event,
          email: email,
          form_slug: form_slug,
          payment_status: :paid,
          status: :purchased
        )
      end

      def blocked_conference_upgrade_ticket(event:, email:, form_slug:)
        conference_upgrade_source_ticket(
          event: event,
          email: email,
          form_slug: form_slug,
          payment_status: %i[pending failed],
          status: :pending_payment
        )
      end

      def conference_upgrade_source_ticket(event:, email:, form_slug:, payment_status:, status:)
        return unless borneo_event_slug?(event)
        return unless conference_like_form_slug?(form_slug)

        normalized_email = email.to_s.strip.downcase
        return if normalized_email.blank?

        event.tickets
             .where(attendee_email_norm: normalized_email)
             .where(payment_status: payment_status, status: status)
             .where.not(status: %i[canceled refunded])
             .includes(:ticket_type)
             .order(:id)
             .find { |ticket| exhibitor_only_ticket_type?(ticket.ticket_type) }
      end

      def borneo_conference_form?(event:, form:)
        borneo_event_slug?(event) && conference_like_form_slug?(form.slug)
      end

      def borneo_combined_ticket_type_ids(event)
        event.ticket_types.select { |ticket_type| borneo_combined_ticket_type?(ticket_type) }.map(&:id)
      end

      def borneo_exhibitor_only_ticket_type_ids(event)
        event.ticket_types.select { |ticket_type| exhibitor_only_ticket_type?(ticket_type) }.map(&:id)
      end

      def borneo_combined_ticket?(event:, ticket:)
        borneo_event_slug?(event) && borneo_combined_ticket_type?(ticket.ticket_type)
      end

      def borneo_combined_ticket_type?(ticket_type)
        name = ticket_type&.name.to_s.downcase
        name.include?('exhibitor') && (name.include?('conference') || name.include?('delegate'))
      end

      def exhibitor_only_ticket_type?(ticket_type)
        name = ticket_type&.name.to_s.downcase
        name.include?('exhibitor') && !conference_like_form_slug?(name)
      end

      def conference_like_form_slug?(value)
        slug = value.to_s.strip.downcase
        return false if slug.blank?

        slug.include?('conference') || slug.include?('delegate')
      end

      def borneo_event_slug?(event)
        event.slug.to_s.strip.downcase.start_with?(BorneoExpoTicketUpgradeService::BORNEO_EVENT_SLUG_PREFIX)
      end

      def auto_paid_ticket?(event:, ticket:, ticket_type:)
        return false unless ticket_type.current_price.zero?
        return true if ticket.registered_by_email.blank?

        leader_email = ticket.registered_by_email.to_s.strip.downcase
        return false if leader_email.blank?

        event.tickets
             .where(payment_status: :paid, status: :purchased)
             .where('LOWER(attendee_email) = ? OR LOWER(registered_by_email) = ?', leader_email, leader_email)
             .exists?
      end

      def apply_bundle_payment_state!(ticket:, bundle:)
        case bundle.payment_status
        when 'not_required', 'paid', 'sponsored'
          ticket.status = 'purchased'
          ticket.payment_status = 'paid'
        else
          ticket.status = 'pending_payment'
          ticket.payment_status = 'pending'
        end
      end

      def resolve_pass_bundle(event:, form:, ticket_type:)
        token = params[:bundle].to_s.strip
        return nil if token.blank?

        bundle = event.pass_bundles.find_by(token: token)
        unless bundle
          render_bundle_error('Invalid or expired bundle link.')
          return nil
        end

        if bundle.expired?
          render_bundle_error('Invalid or expired bundle link.')
          return nil
        end

        if bundle.paused?
          render_bundle_error('This bundle is paused. Please contact the organizer.')
          return nil
        end

        if form.blank? || bundle.registration_form_id != form.id
          render_bundle_error('This bundle link is not valid for this registration form.')
          return nil
        end

        if bundle.ticket_type_id != ticket_type.id
          render_bundle_error('This bundle link is not valid for the selected pass.')
          return nil
        end

        if bundle.full?
          render_bundle_error('This bundle is full. Please contact the organizer.')
          return nil
        end

        bundle
      end

      def render_bundle_error(message)
        render json: {
          success: false,
          message: message
        }, status: :unprocessable_content
      end
    end
  end
end
