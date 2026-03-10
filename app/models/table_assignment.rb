class TableAssignment < ApplicationRecord
  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true
  belongs_to :plan_object

  validates :ticket_id, uniqueness: { message: "is already assigned to a table" }, allow_nil: true
  validates :visitor_id, uniqueness: { message: "is already assigned to a table" }, allow_nil: true
  
  validate :exactly_one_participant
  validate :plan_object_must_be_table

  private

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
end