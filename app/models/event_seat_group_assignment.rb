class EventSeatGroupAssignment < ApplicationRecord
  belongs_to :event_seat_group
  belongs_to :event_ticket_seat

  validates :event_ticket_seat_id, uniqueness: true

  after_commit :sync_ticketing, on: [:create, :destroy]

  private

  def sync_ticketing
    # Sync the group it belongs/belonged to
    SeatTicketing::SyncService.sync_group(event_seat_group) if event_seat_group
    
    # Sync the section to update standard quantity
    if event_ticket_seat&.event_seat_section
      SeatTicketing::SyncService.sync_section(event_ticket_seat.event_seat_section)
    end
  end
end
