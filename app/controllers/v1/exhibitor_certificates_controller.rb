module V1
  # E-certificates for exhibitor companies: one per company, sent manually by the organizer.
  class ExhibitorCertificatesController < ApplicationController
    before_action :set_event_and_authorize

    # GET /v1/events/:event_id/exhibitor_certificates
    def index
      authorize @event, :preview?, policy_class: CertificateTemplatePolicy

      latest = latest_deliveries_by_exhibitor_id
      render json: { data: certificates.map { |cert| row(cert, latest[cert.exhibitor.id]) } }, status: :ok
    end

    # GET /v1/events/:event_id/exhibitor_certificates/preview
    # Query: exhibitor_id (optional, else a sample), download=true (optional)
    def preview
      authorize @event, :preview?, policy_class: CertificateTemplatePolicy
      return render_no_template unless template&.background_image&.attached?

      cert = certificates.find { |c| c.exhibitor.id == params[:exhibitor_id].to_i } if params[:exhibitor_id].present?
      pdf = CertificatePdfGenerator.new(template, nil, exhibitor: cert, sample_name: 'Company Name').render

      send_data pdf, filename: 'certificate.pdf', type: 'application/pdf',
                     disposition: ActiveModel::Type::Boolean.new.cast(params[:download]) ? 'attachment' : 'inline'
    end

    # GET /v1/events/:event_id/exhibitor_certificates/download_all
    # One multi-page PDF, one certificate per eligible company.
    def download_all
      authorize @event, :preview?, policy_class: CertificateTemplatePolicy
      return render_no_template unless template&.background_image&.attached?

      pdf = CertificatePdfGenerator.render_exhibitor_batch(template, certificates)
      return render json: { errors: ['No eligible exhibitors to download'] }, status: :unprocessable_content if pdf.nil?

      send_data pdf, filename: "exhibitor-certificates-#{@event.slug.presence || @event.id}.pdf",
                     type: 'application/pdf', disposition: 'attachment'
    end

    # POST /v1/events/:event_id/exhibitor_certificates/send_one
    # Body: { exhibitor_id }
    def send_one
      authorize @event, :send_batch?, policy_class: CertificateTemplatePolicy
      return render_template_not_ready unless template&.ready?

      cert = certificates.find { |c| c.exhibitor.id == params[:exhibitor_id].to_i }
      return render json: { errors: ['Exhibitor is not eligible for a certificate'] }, status: :not_found if cert.nil?
      return render json: { errors: ['This exhibitor has no email'] }, status: :unprocessable_content if cert.email.blank?

      delivery = deliver(cert, 'exhibitor_certificate_send_one')
      render json: { message: 'Certificate has been queued for sending', email_delivery_id: delivery.id },
             status: :accepted
    end

    # POST /v1/events/:event_id/exhibitor_certificates/send_batch
    # Body: { skip_sent: Boolean } — send to every eligible company that has an email.
    def send_batch
      authorize @event, :send_batch?, policy_class: CertificateTemplatePolicy
      return render_template_not_ready unless template&.ready?

      sent_ids = ActiveModel::Type::Boolean.new.cast(params[:skip_sent]) ? delivered_exhibitor_ids : []
      with_email, without_email = certificates.reject { |c| sent_ids.include?(c.exhibitor.id) }
                                              .partition { |c| c.email.present? }
      with_email.each { |cert| deliver(cert, 'exhibitor_certificate_send') }

      render json: { message: 'Certificates have been queued for sending',
                     queued: with_email.size, skipped_no_email: without_email.size }, status: :accepted
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :show?
    end

    def template
      @template ||= @event.exhibitor_certificate_template
    end

    def certificates
      @certificates ||= ExhibitorCertificate.for_event(@event)
    end

    def deliver(cert, source)
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'CertificateMailer',
        mailer_action: 'exhibitor_certificate_email',
        args: [cert.exhibitor],
        related: cert.exhibitor,
        event: @event,
        # Always an explicit organizer action, so it bypasses the 24h duplicate guard.
        metadata: { source: source, event_id: @event.id, actor_id: current_user&.id }
      )
    end

    def exhibitor_deliveries
      EmailDelivery.where(related_type: 'EventVendor', mailer_action: 'exhibitor_certificate_email',
                          related_id: certificates.map { |c| c.exhibitor.id })
    end

    def latest_deliveries_by_exhibitor_id
      exhibitor_deliveries.order(created_at: :desc).each_with_object({}) { |d, acc| acc[d.related_id] ||= d }
    end

    def delivered_exhibitor_ids
      exhibitor_deliveries.where(status: SendEventCertificatesJob::SENT_STATUSES).distinct.pluck(:related_id)
    end

    def row(cert, delivery)
      {
        exhibitor_id: cert.exhibitor.id,
        company_name: cert.company_name,
        email: cert.email,
        booth_count: cert.booth_count,
        booth_numbers: cert.booth_numbers,
        certificate_status: delivery&.status,
        certificate_sent_at: delivery&.sent_at,
        last_delivery_id: delivery&.id
      }
    end

    def render_no_template
      render json: { errors: ['Exhibitor certificate template is not configured'] }, status: :unprocessable_content
    end

    def render_template_not_ready
      render json: { errors: ['Exhibitor certificate template is not ready to send'] }, status: :unprocessable_content
    end
  end
end
