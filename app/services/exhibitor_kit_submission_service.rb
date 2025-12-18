class ExhibitorKitSubmissionService < BaseService
  attr_reader :exhibitor_kit

  def initialize(user:, exhibitor_kit:)
    super(user, {})
    @exhibitor_kit = exhibitor_kit
  end

  def call
    validate_submission!

    ActiveRecord::Base.transaction do
      payment = create_payment
      link_items_to_payment(payment)
      link_printings_to_payment(payment)

      ServiceResult.new(success: true, data: payment, status: :created)
    end
  rescue CustomError::UnprocessableEntity => e
    ServiceResult.new(success: false, errors: e.message, status: :unprocessable_content)
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.new(success: false, errors: e.record.errors.full_messages, status: :unprocessable_content)
  end

  private

  def validate_submission!
    unless contractor_user.present?
      raise CustomError::UnprocessableEntity.new("No contractor assigned to this event")
    end

    if unpaid_items.empty? && unpaid_printings.empty?
      raise CustomError::UnprocessableEntity.new("No unpaid items or printings to submit")
    end
  end

  def create_payment
    ExhibitorKitPayment.create!(
      exhibitor_kit: exhibitor_kit,
      payee: contractor_user,
      amount: calculate_total_amount,
      status: :pending
    )
  end

  def link_items_to_payment(payment)
    unpaid_items.update_all(exhibitor_kit_payment_id: payment.id)
  end

  def link_printings_to_payment(payment)
    unpaid_printings.update_all(exhibitor_kit_payment_id: payment.id)
  end

  def calculate_total_amount
    items_total = unpaid_items.sum("quantity * agreed_price")
    printings_total = unpaid_printings.sum("quantity * agreed_price")
    items_total + printings_total
  end

  def unpaid_items
    @unpaid_items ||= exhibitor_kit.exhibitor_kit_items.where(exhibitor_kit_payment_id: nil)
  end

  def unpaid_printings
    @unpaid_printings ||= exhibitor_kit.exhibitor_kit_printings.where(exhibitor_kit_payment_id: nil)
  end

  def contractor_user
    @contractor_user ||= exhibitor_kit.event
                                      &.event_exhibition_contractor
                                      &.exhibition_contractor_profile
                                      &.user
  end
end
