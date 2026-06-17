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

    args = EmailDelivery::ArgsRebuilder.call(@delivery)
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

  def failure(message)
    Result.new(success: false, delivery: nil, errors: [message])
  end
end
