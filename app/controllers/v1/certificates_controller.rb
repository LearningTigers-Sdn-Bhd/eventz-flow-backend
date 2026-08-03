module V1
  class CertificatesController < ApplicationController
    before_action :set_event_and_authorize

    # POST /v1/events/:event_id/certificates/send_batch
    # Body: { audience: "all" | "checked_in", excluded_ticket_ids: [Integer] }
    def send_batch
      authorize @event, :send_batch?, policy_class: CertificateTemplatePolicy

      template = @event.certificate_template
      unless template&.ready?
        return render json: { errors: ['Certificate template is not ready to send'] },
                      status: :unprocessable_content
      end

      audience = resolved_audience
      excluded = excluded_public_ids

      queued = SendEventCertificatesJob.recipient_scope(@event, audience, excluded).count
      skipped = skipped_no_email_count(audience, excluded)

      SendEventCertificatesJob.perform_later(@event.id, audience, excluded, current_user&.id)

      render json: {
        message: 'Certificates have been queued for sending',
        audience: audience,
        queued: queued,
        skipped_no_email: skipped
      }, status: :accepted
    end

    # GET /v1/events/:event_id/certificates/preview
    # Query: ticket_id (optional), download=true (optional)
    def preview
      authorize @event, :preview?, policy_class: CertificateTemplatePolicy

      template = @event.certificate_template
      unless template.present? && template.background_image.attached?
        return render json: { errors: ['Certificate template is not configured'] },
                      status: :unprocessable_content
      end

      ticket = params[:ticket_id].present? ? @event.tickets.find_by(public_id: params[:ticket_id]) : nil
      sample_name = ticket ? nil : 'Attendee Name'

      pdf = CertificatePdfGenerator.new(template, ticket, sample_name: sample_name).render

      send_data pdf,
                filename: 'certificate.pdf',
                type: 'application/pdf',
                disposition: ActiveModel::Type::Boolean.new.cast(params[:download]) ? 'attachment' : 'inline'
    end

    # GET /v1/events/:event_id/certificates/download_all
    # Query: audience ("all" | "checked_in" | "unsent")
    # Returns a single multi-page PDF, one certificate per matching attendee.
    def download_all
      authorize @event, :preview?, policy_class: CertificateTemplatePolicy

      template = @event.certificate_template
      unless template.present? && template.background_image.attached?
        return render json: { errors: ['Certificate template is not configured'] },
                      status: :unprocessable_content
      end

      tickets = SendEventCertificatesJob.recipient_scope(@event, resolved_audience)
                                        .order(:attendee_name)

      pdf = CertificatePdfGenerator.render_batch(template, tickets)
      if pdf.nil?
        return render json: { errors: ['No matching attendees to download'] },
                      status: :unprocessable_content
      end

      send_data pdf,
                filename: "certificates-#{@event.slug.presence || @event.id}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    # GET /v1/events/:event_id/certificates/participants
    # One row per ticket holder, with the latest certificate delivery status.
    def participants
      authorize @event, :preview?, policy_class: CertificateTemplatePolicy

      tickets = @event.tickets.where.not(attendee_email: [nil, '']).order(:attendee_name)
      latest = latest_certificate_deliveries_by_ticket_id

      render json: {
        data: tickets.map { |ticket| participant_row(ticket, latest[ticket.id]) }
      }, status: :ok
    end

    # POST /v1/events/:event_id/certificates/send_one
    # Body: { public_id: "..." } — send/resend a certificate to one ticket holder.
    def send_one
      authorize @event, :send_batch?, policy_class: CertificateTemplatePolicy

      template = @event.certificate_template
      unless template&.ready?
        return render json: { errors: ['Certificate template is not ready to send'] },
                      status: :unprocessable_content
      end

      ticket = @event.tickets.find_by(public_id: params[:public_id])
      if ticket.nil?
        return render json: { errors: ['Ticket not found'] }, status: :not_found
      end

      if ticket.attendee_email.blank?
        return render json: { errors: ['This ticket has no attendee email'] },
                      status: :unprocessable_content
      end

      if ticket.waiting_list?
        return render json: { errors: ['Ticket is on the waiting list and has not been confirmed'] },
                      status: :unprocessable_content
      end

      delivery = EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'CertificateMailer',
        mailer_action: 'certificate_email',
        args: [ticket],
        related: ticket,
        metadata: {
          source: 'certificate_send_one',
          event_id: @event.id,
          actor_id: current_user&.id
        }
      )

      render json: {
        message: 'Certificate has been queued for sending',
        email_delivery_id: delivery.id
      }, status: :accepted
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :show?
    end

    # Builds { ticket_id => EmailDelivery } for the most recent certificate
    # delivery per ticket in this event (single query, no N+1).
    def latest_certificate_deliveries_by_ticket_id
      EmailDelivery
        .where(related_type: 'Ticket', mailer_action: 'certificate_email')
        .where(related_id: @event.tickets.select(:id))
        .order(created_at: :desc)
        .each_with_object({}) do |delivery, acc|
          acc[delivery.related_id] ||= delivery
        end
    end

    def participant_row(ticket, delivery)
      {
        public_id: ticket.public_id,
        attendee_name: ticket.attendee_name,
        attendee_email: ticket.attendee_email,
        ticket_type: ticket.ticket_type&.name,
        checked_in: ticket.checked_in,
        certificate_status: delivery&.status,
        certificate_sent_at: delivery&.sent_at,
        last_delivery_id: delivery&.id
      }
    end

    def resolved_audience
      audience = params[:audience].to_s
      SendEventCertificatesJob::AUDIENCES.include?(audience) ? audience : 'all'
    end

    def excluded_public_ids
      Array(params[:excluded_public_ids]).map(&:to_s).reject(&:blank?)
    end

    def skipped_no_email_count(audience, excluded)
      scope = @event.tickets
      scope = scope.where(checked_in: true) if audience == 'checked_in'
      scope = scope.where.not(public_id: excluded) if excluded.present?
      scope.where(attendee_email: [nil, '']).count
    end
  end
end
