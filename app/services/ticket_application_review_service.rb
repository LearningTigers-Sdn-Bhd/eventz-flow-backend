class TicketApplicationReviewService
  Result = Struct.new(:success, :application, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(ticket_application, reviewer: nil)
    @application = ticket_application
    @ticket = ticket_application.ticket
    @event = @ticket.event
    @setting = ticket_application.registration_form.registration_form_rsvp_setting
    @reviewer = reviewer
  end

  def approve!
    raw_token = nil

    TicketApplication.transaction do
      @application.update!(
        review_status: :approved,
        reviewed_by: @reviewer,
        reviewed_at: Time.current
      )

      if rsvp_required?
        raw_token = send_rsvp!
      else
        purchase_ticket!
      end
    end

    raw_token
  end

  def reject!(reason: nil)
    TicketApplication.transaction do
      @application.update!(
        review_status: :rejected,
        reviewed_by: @reviewer,
        reviewed_at: Time.current,
        rejection_reason: reason
      )
      @ticket.update!(status: :canceled)
    end

    if @ticket.attendee_email.present?
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketApplicationMailer',
        mailer_action: 'rejection',
        args: [@application],
        related: @application
      )
    end
    Result.new(success: true, application: @application)
  end

  def revert_to_pending!(confirm_manual_refund: false)
    return Result.new(success: false, application: @application, error: 'Application is not approved') unless @application.approved?
    return Result.new(success: false, application: @application, error: 'Ticket already checked in, cannot revert') if @ticket.scanned?

    if gateway_paid? && !confirm_manual_refund
      return Result.new(success: false, application: @application, error: 'Ticket was paid via payment gateway. Refund it first, then confirm.')
    end

    TicketApplication.transaction do
      @application.update!(
        review_status: :pending_review,
        reviewed_by: nil,
        reviewed_at: nil,
        rsvp_status: :not_sent,
        rsvp_token_digest: nil,
        rsvp_sent_at: nil,
        rsvp_expires_at: nil,
        rsvp_confirmed_at: nil
      )
      @ticket.update!(status: :pending_payment, payment_status: :pending)
      @ticket.ticket_payment&.update!(status: 'refunded') if @ticket.ticket_payment&.status == 'paid'
    end

    Result.new(success: true, application: @application)
  end

  def resend_rsvp!
    return Result.new(success: false, application: @application, error: 'Application is not approved') unless @application.approved?
    return Result.new(success: false, application: @application, error: 'RSVP already confirmed') if @application.confirmed?
    return Result.new(success: false, application: @application, error: 'Application was rejected') if @application.rejected?

    send_rsvp!

    Result.new(success: true, application: @application)
  end

  def confirm_rsvp!(raw_token:)
    return Result.new(success: false, application: @application, error: 'Invalid RSVP link') unless @application.matches_rsvp_token?(raw_token)
    return Result.new(success: false, application: @application, error: 'Application is not approved') unless @application.approved?
    return Result.new(success: false, application: @application, error: 'RSVP was declined') if @application.declined?

    if @application.confirmed?
      return Result.new(success: true, application: @application)
    end

    if @application.expired?
      @application.update!(rsvp_status: :expired)
      return Result.new(success: false, application: @application, error: 'RSVP link has expired')
    end

    TicketApplication.transaction do
      @application.update!(rsvp_status: :confirmed, rsvp_confirmed_at: Time.current)
      purchase_ticket!
    end

    Result.new(success: true, application: @application)
  end

  def decline_rsvp!(raw_token:)
    return Result.new(success: false, application: @application, error: 'Invalid RSVP link') unless @application.matches_rsvp_token?(raw_token)
    return Result.new(success: false, application: @application, error: 'RSVP already confirmed') if @application.confirmed?

    @application.update!(rsvp_status: :declined)
    Result.new(success: true, application: @application)
  end

  def approve_rsvp!
    return Result.new(success: false, application: @application, error: 'Application is not approved') unless @application.approved?
    return Result.new(success: true, application: @application) if @application.confirmed?
    return Result.new(success: false, application: @application, error: 'RSVP was declined') if @application.declined?

    TicketApplication.transaction do
      @application.update!(rsvp_status: :confirmed, rsvp_confirmed_at: Time.current)
      purchase_ticket!
    end

    Result.new(success: true, application: @application)
  end

  private

  def rsvp_required?
    @setting&.enabled? && @setting&.rsvp_required?
  end

  def gateway_paid?
    payment = @ticket.ticket_payment
    payment.present? && payment.status == 'paid' && payment.gateway.present?
  end

  def send_rsvp!
    raw_token = @application.assign_rsvp_token!
    @application.update!(
      rsvp_status: :sent,
      rsvp_sent_at: Time.current,
      rsvp_expires_at: expiry_time
    )
    if @ticket.attendee_email.present?
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'TicketApplicationMailer',
        mailer_action: 'rsvp_invitation',
        args: [@application, raw_token],
        related: @application
      )
    end
    raw_token
  end

  def expiry_time
    return nil if @setting&.rsvp_expires_in_hours.blank?

    @setting.rsvp_expires_in_hours.hours.from_now
  end

  def purchase_ticket!
    @ticket.update!(payment_status: :paid, status: :purchased)
  end
end
