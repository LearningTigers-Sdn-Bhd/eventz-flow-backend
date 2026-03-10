class EventSeatingGroup < ApplicationRecord
  belongs_to :event
  belongs_to :plan, optional: true

  has_many :event_seating_group_members, dependent: :destroy

  enum :scope, { plan_only: 0, event_level: 1 }

  validates :name, presence: true
  validates :scope, presence: true
  validate :plan_presence_for_scope
  validate :plan_belongs_to_event

  before_validation :apply_scope_defaults

  scope :visible_for_plan, ->(plan) do
    where(event_id: plan.event_id).where(
      "scope = :event_level OR (scope = :plan_only AND plan_id = :plan_id)",
      event_level: scopes[:event_level],
      plan_only: scopes[:plan_only],
      plan_id: plan.id
    )
  end

  private

  def apply_scope_defaults
    self.scope ||= :plan_only
    self.plan_id = nil if event_level?
  end

  def plan_presence_for_scope
    return unless plan_only?
    return if plan_id.present?

    errors.add(:plan, "must be present for plan-only groups")
  end

  def plan_belongs_to_event
    return if plan.blank? || event.blank?
    return if plan.event_id == event_id

    errors.add(:plan, "must belong to the same event")
  end
end
