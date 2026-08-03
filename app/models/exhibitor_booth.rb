class ExhibitorBooth < ApplicationRecord
  belongs_to :event
  belongs_to :exhibitor_booth_price
  belongs_to :exhibitor_kit, optional: true

  enum :status, { available: 0, reserved: 1, booked: 2, blocked: 3 }

  before_validation :normalize_number

  validates :number, presence: true, uniqueness: { scope: :event_id }
  validate :booth_price_must_belong_to_event

  # A booth is bookable when it is free, or when it is marked reserved but the kit holding it
  # has let go: the booking was cancelled or expired, or its hold lapsed. Expiry is evaluated at
  # read time so no sweeper job is needed.
  scope :bookable, lambda {
    left_joins(:exhibitor_kit).where(
      'exhibitor_booths.status = :available
       OR (exhibitor_booths.status = :reserved
           AND (exhibitor_kits.id IS NULL
                OR exhibitor_kits.booking_status IN (:released)
                OR (exhibitor_kits.booking_status = :active
                    AND exhibitor_kits.reservation_expires_at IS NOT NULL
                    AND exhibitor_kits.reservation_expires_at <= :now)))',
      available: statuses[:available],
      reserved: statuses[:reserved],
      released: [ExhibitorKit.booking_statuses[:cancelled], ExhibitorKit.booking_statuses[:expired]],
      active: ExhibitorKit.booking_statuses[:active],
      now: Time.current
    )
  }

  # ponytail: re-queries rather than duplicating the SQL rule in Ruby. One definition of bookable.
  def bookable?
    self.class.bookable.exists?(id: id)
  end

  private

  def normalize_number
    self.number = number.to_s.strip.upcase.presence
  end

  def booth_price_must_belong_to_event
    return if exhibitor_booth_price.blank? || exhibitor_booth_price.event_id == event_id

    errors.add(:exhibitor_booth_price_id, 'must belong to the same event')
  end
end
