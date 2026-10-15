# A timed session of the event. Defined by staff, never by a scan.
module Rfid
  class Session < ApplicationRecord
    self.table_name = 'rfid_sessions'

    belongs_to :event

    validates :name, presence: true, length: { maximum: 255 }
    validates :starts_at, :ends_at, presence: true
    validate :ends_after_start

    def duration_seconds
      (ends_at - starts_at).to_i
    end

    private

    def ends_after_start
      return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

      errors.add(:ends_at, 'must be after the start')
    end
  end
end
