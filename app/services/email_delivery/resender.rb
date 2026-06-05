class EmailDelivery::Resender
  class Result
    attr_reader :delivery, :errors

    def initialize(success:, delivery: nil, errors: [])
      @success = success
      @delivery = delivery
      @errors = errors
    end

    def success?
      @success
    end
  end

  def self.call(delivery)
    new(delivery).call
  end

  def initialize(delivery)
    @delivery = delivery
  end

  def call
    return failure('Email is not eligible for resend') unless @delivery.eligible_for_manual_resend?

    args = rebuild_args
    return failure('Email type is not supported for resend') unless args

    new_delivery = EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: @delivery.mailer_name,
      mailer_action: @delivery.mailer_action,
      args: args,
      related: @delivery.related,
      metadata: (@delivery.metadata || {}).merge(resend_of_id: @delivery.id)
    )
    new_delivery.update!(resend_of: @delivery)

    Result.new(success: true, delivery: new_delivery, errors: [])
  end

  private

  def rebuild_args
    case [@delivery.mailer_name, @delivery.mailer_action]
    when ['TicketMailer', 'confirmation_email']
      [@delivery.related].compact if @delivery.related.is_a?(Ticket)
    when ['ExhibitorRegistrationMailer', 'registration_received_email'],
         ['ExhibitorRegistrationMailer', 'payment_confirmed_email']
      [@delivery.related].compact if @delivery.related.is_a?(ExhibitorKit)
    when ['TicketApplicationMailer', 'acknowledgement'],
         ['TicketApplicationMailer', 'rejection']
      [@delivery.related].compact if @delivery.related.is_a?(TicketApplication)
    when ['TicketApplicationMailer', 'rsvp_invitation']
      return unless @delivery.related.is_a?(TicketApplication)

      raw_token = @delivery.related.assign_rsvp_token!
      @delivery.related.update!(rsvp_status: :sent, rsvp_sent_at: Time.current)
      [@delivery.related, raw_token]
    when ['UserMailer', 'verification_code']
      return unless @delivery.related.is_a?(User)

      code = EmailVerification.create_for_user(@delivery.related)
      [@delivery.related, code]
    when ['UserMailer', 'password_reset']
      return unless @delivery.related.is_a?(User)

      raw_token = PasswordReset.issue_for!(@delivery.related)
      [@delivery.related, raw_token]
    end
  end

  def failure(message)
    Result.new(success: false, delivery: nil, errors: [message])
  end
end
