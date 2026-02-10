class EventTicketSeat < ApplicationRecord
  belongs_to :event_seat_section
  delegate :event, to: :event_seat_section, allow_nil: true

  belongs_to :ticket, optional: true
  belongs_to :visitor, optional: true
  belongs_to :ticket_type, optional: true

  has_one :event_seat_group_assignment, dependent: :destroy
  has_one :event_seat_group, through: :event_seat_group_assignment
  accepts_nested_attributes_for :event_seat_group_assignment, allow_destroy: true

  validates :name, presence: true

  after_commit :sync_ticket_type, on: [:create, :update]
  after_commit :sync_parent_on_destroy, on: :destroy

  after_commit :broadcast_update

  def status
    return 'available' if event.nil?

    if event.use_ticket?
      return 'sold' if ticket_id.present?
    else
      return 'sold' if visitor_id.present?
    end

    if locked_by_session_id.present?
      checkout_session = EventSeatCheckoutSession.find_by(id: locked_by_session_id)
      if checkout_session.nil? || checkout_session.expired?
        clear_expired_lock
      else
        return 'locked'
      end
    end
    'available'
  end

  def locked?
    status == 'locked'
  end

  def sold?
    status == 'sold'
  end

  def available?
    status == 'available'
  end

  def as_json(options = {})
    json = super(options)
    json['status'] = status
    json['locked_by_session_id'] = locked_by_session_id
    json
  end

  private

  def sync_ticket_type
    return unless event&.use_ticket?
    
    # If seat was just assigned to a group, sync the group
    if previous_changes[:id].present? || previous_changes[:extra_price].present? || previous_changes[:ticket_type_id].present? || previous_changes[:name].present?
      SeatTicketing::SyncService.sync_seat(self)
    end
    
    # Always sync parent section/group to update quantities
    sync_parent
  end

  def sync_parent
    return unless event&.use_ticket?
    
    if event_seat_group.present?
      SeatTicketing::SyncService.sync_group(event_seat_group)
    else
      SeatTicketing::SyncService.sync_section(event_seat_section)
    end
  end

  def sync_parent_on_destroy
    return unless event&.use_ticket?
    # Cannot use event_seat_group association directly if destroyed
    # but we should have section_id
    section = EventSeatSection.find_by(id: event_seat_section_id)
    SeatTicketing::SyncService.sync_section(section) if section
  end

  def clear_expired_lock
    update!(locked_by_session_id: nil)
  rescue ActiveRecord::ActiveRecordError
    nil
  end

  def broadcast_update
    session = event_seat_section.event_seat_venue.event_seat_session
    ActionCable.server.broadcast(
      "event_seat_session_#{session.public_id}",
      {
        type: 'seat_updated',
        seat: self.as_json(only: [:id, :event_seat_section_id, :name, :extra_price, :row_set, :col_set, :ticket_id, :visitor_id, :locked_by_session_id])
      }
    )
  end
end
