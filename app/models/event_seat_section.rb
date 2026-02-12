class EventSeatSection < ApplicationRecord
  belongs_to :event_seat_venue
  belongs_to :ticket_type, optional: true
  delegate :event, to: :event_seat_venue, allow_nil: true
  delegate :event_seat_session, to: :event_seat_venue, allow_nil: true

  has_many :event_ticket_seats, dependent: :destroy
  has_many :event_seat_groups, dependent: :destroy
  accepts_nested_attributes_for :event_ticket_seats, allow_destroy: true
  accepts_nested_attributes_for :event_seat_groups, allow_destroy: true

  attr_accessor :blueprint_config

  validates :name, presence: true

  after_commit :sync_ticket_type, on: [:create, :update]

  def seats_count
    event_ticket_seats.count
  end

  private

  def sync_ticket_type
    return unless event&.use_ticket?
    return if destroyed?
    
    # Avoid sync if no relevant changes
    relevant_keys = %w[name price ticket_type_id]
    return if !previous_changes.keys.any? { |k| k.in?(relevant_keys) } && !id_previously_changed?

    SeatTicketing::SyncService.sync_section(self)
  end
end