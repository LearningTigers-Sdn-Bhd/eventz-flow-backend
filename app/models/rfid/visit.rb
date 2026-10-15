# A derived visit: entry opens it, the next accepted exit closes it. The row
# is a projection of authoritative observations plus explicit corrections and
# can be rebuilt at any time, so nothing here is a source of truth for replay.
module Rfid
  class Visit < ApplicationRecord
    self.table_name = 'rfid_visits'

    belongs_to :event
    belongs_to :ticket, optional: true
    belongs_to :entry_observation, class_name: 'Rfid::Observation', optional: true
    belongs_to :correction, class_name: 'Rfid::Correction', optional: true
    belongs_to :exit_observation, class_name: 'Rfid::Observation', optional: true

    scope :open, -> { where(exit_at: nil) }
    scope :closed, -> { where.not(exit_at: nil) }

    def open?
      exit_at.nil?
    end

    # Only a closed visit has a duration; an open one counts towards live
    # headcount and nothing else.
    def duration_seconds
      return nil if exit_at.nil?

      (exit_at - entry_at).round
    end
  end
end
