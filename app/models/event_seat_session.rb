class EventSeatSession < ApplicationRecord
  belongs_to :event
  has_many :event_seat_venues, dependent: :destroy
  accepts_nested_attributes_for :event_seat_venues, allow_destroy: true

  enum :status, { draft: 0, published: 1, cancelled: 2 }

  validates :name, presence: true
  validates :start_datetime, presence: true
  validates :end_datetime, presence: true
  validate :end_date_after_start_date

  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }

  def archive
    update(deleted_at: Time.current)
  end

  def restore
    update(deleted_at: nil)
  end

  private

  def end_date_after_start_date
    return if end_datetime.blank? || start_datetime.blank?

    if end_datetime < start_datetime
      errors.add(:end_datetime, "must be after the start date")
    end
  end
end
