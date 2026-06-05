class EventSeatingGroupMember < ApplicationRecord
  PARTICIPANT_TYPES = %w[Ticket Visitor].freeze

  belongs_to :event_seating_group
  belongs_to :participant, polymorphic: true

  validates :participant_type, inclusion: { in: PARTICIPANT_TYPES }
  validates :participant_id, uniqueness: { scope: :participant_type }
  validate :participant_belongs_to_group_event

  private

  def participant_belongs_to_group_event
    return if participant.blank? || event_seating_group.blank?
    return if participant.event_id == event_seating_group.event_id

    errors.add(:participant, "must belong to the same event as the group")
  end
end
