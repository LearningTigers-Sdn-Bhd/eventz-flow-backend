class ExhibitorKitSubmissionService < BaseService
  attr_reader :exhibitor_kit

  def initialize(user:, exhibitor_kit:)
    super(user, {})
    @exhibitor_kit = exhibitor_kit
  end

  def call
    validate_submission!

    ActiveRecord::Base.transaction do
      payments = create_payments_by_owner
      ServiceResult.new(success: true, data: payments, status: :created)
    end
  rescue CustomError::UnprocessableEntity => e
    ServiceResult.new(success: false, errors: e.message, status: :unprocessable_content)
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.new(success: false, errors: e.record.errors.full_messages, status: :unprocessable_content)
  end

  private

  def validate_submission!
    if unpaid_items_with_owner.empty? && unpaid_printings_with_owner.empty?
      raise CustomError::UnprocessableEntity.new("No unpaid items or printings to submit")
    end
  end

  def create_payments_by_owner
    payments = []

    # Group items by owner with eager loading
    items_by_owner = unpaid_items_with_owner.group_by { |i| i.rentable_item.user_id }
    services_by_owner = unpaid_printings_with_owner.group_by { |p| p.printing_service.user_id }

    # Get all unique owners
    owner_ids = (items_by_owner.keys + services_by_owner.keys).compact.uniq

    owner_ids.each do |owner_id|
      owner_items = items_by_owner[owner_id] || []
      owner_services = services_by_owner[owner_id] || []

      payment = create_payment_for_owner(owner_id, owner_items, owner_services)
      payments << payment
    end

    payments
  end

  def create_payment_for_owner(owner_id, items, services)
    total = calculate_total(items, services)

    payment = ExhibitorKitPayment.create!(
      exhibitor_kit: exhibitor_kit,
      payee_id: owner_id,
      amount: total,
      status: :pending
    )

    # Batch update - efficient
    ExhibitorKitItem.where(id: items.map(&:id)).update_all(exhibitor_kit_payment_id: payment.id) if items.any?
    ExhibitorKitPrinting.where(id: services.map(&:id)).update_all(exhibitor_kit_payment_id: payment.id) if services.any?

    payment
  end

  def calculate_total(items, services)
    items_total = items.sum { |i| i.quantity * i.agreed_price }
    services_total = services.sum { |s| s.quantity * s.agreed_price }
    items_total + services_total
  end

  def unpaid_items_with_owner
    @unpaid_items_with_owner ||= exhibitor_kit
      .exhibitor_kit_items
      .includes(:rentable_item)
      .where(exhibitor_kit_payment_id: nil)
      .where.not(rentable_items: { id: nil })
  end

  def unpaid_printings_with_owner
    @unpaid_printings_with_owner ||= exhibitor_kit
      .exhibitor_kit_printings
      .includes(:printing_service)
      .where(exhibitor_kit_payment_id: nil)
      .where.not(printing_services: { id: nil })
  end
end
