# One room/track of an event (e.g. BTH Summit's 4 rooms). Paid tickets are
# split across an event's groups by TicketGroupAssigner; the optional
# priority ticket type is filled into this group first.
class TicketGroup < ApplicationRecord
  belongs_to :event
  has_many :tickets, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  before_validation { self.priority_ticket_type_ids = priority_ticket_type_ids.uniq }
  validates :position, presence: true, uniqueness: { scope: :event_id }
  validate :priority_types_belong_to_event

  default_scope { order(:position) }

  private

  def priority_types_belong_to_event
    return if priority_ticket_type_ids.empty?
    return if event.ticket_types.where(id: priority_ticket_type_ids).count == priority_ticket_type_ids.uniq.size

    errors.add(:priority_ticket_type_ids, 'must all belong to this event')
  end
end
