class EventSeatGroup < ApplicationRecord
  belongs_to :event_seat_section
  belongs_to :ticket_type, optional: true
  
  has_many :event_seat_group_assignments, dependent: :destroy
  has_many :event_ticket_seats, through: :event_seat_group_assignments
  accepts_nested_attributes_for :event_seat_group_assignments, allow_destroy: true

  validates :name, presence: true
  validates :extra_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  delegate :event, to: :event_seat_section, allow_nil: true

  after_commit :sync_ticket_type, on: [:create, :update]

  private

  def sync_ticket_type
    return unless event&.use_ticket?
    return if destroyed?

    relevant_keys = %w[name extra_price ticket_type_id]
    return if !previous_changes.keys.any? { |k| k.in?(relevant_keys) } && !id_previously_changed?

    SeatTicketing::SyncService.sync_group(self)
  end
end
