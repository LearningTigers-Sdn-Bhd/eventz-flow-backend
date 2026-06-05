class TableAssignment < ApplicationRecord
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true
  belongs_to :plan_object

  validate :unique_participant_per_plan
  validate :exactly_one_participant
  validate :plan_object_must_be_table
  validate :table_capacity_available

  def insufficient_space_payload(required_seats: 1)
    remaining = remaining_capacity
    needed = [required_seats - remaining, 0].max

    {
      error: "insufficient_space",
      message: "Insufficient space. Table has #{remaining} seat(s) remaining. Clear #{needed} seat(s) to fit.",
      required_seats: required_seats,
      remaining_seats: remaining,
      needed_to_fit: needed
    }
  end

  private

  def unique_participant_per_plan
    plan_id = plan_object&.plan_id
    return unless plan_id

    scope = TableAssignment.joins(:plan_object).where(plan_objects: { plan_id: plan_id })
    scope = scope.where.not(id: id) if persisted?
    
    if ticket_id.present? && scope.exists?(ticket_id: ticket_id)
      errors.add(:ticket_id, "is already assigned to a table in this plan")
    elsif visitor_id.present? && scope.exists?(visitor_id: visitor_id)
      errors.add(:visitor_id, "is already assigned to a table in this plan")
    end
  end

  def exactly_one_participant
    if ticket_id.present? && visitor_id.present?
      errors.add(:base, "Cannot assign both ticket and visitor to the same seat")
    elsif ticket_id.blank? && visitor_id.blank?
      errors.add(:base, "Must assign either a ticket or a visitor")
    end
  end

  def plan_object_must_be_table
    return unless plan_object
    unless plan_object.object_type_table?
      errors.add(:plan_object, "must be a table")
    end
  end

  def table_capacity_available
    return unless plan_object&.object_type_table?
    return if plan_object.capacity.nil?
    return if remaining_capacity >= 1

    payload = insufficient_space_payload(required_seats: 1)
    errors.add(:base, :insufficient_space, message: payload[:message])
  end

  def remaining_capacity
    return 0 unless plan_object&.object_type_table?
    return 0 if plan_object.capacity.nil?

    assigned_count = plan_object.table_assignments.where.not(id: id).count
    [plan_object.capacity - assigned_count, 0].max
  end
end
