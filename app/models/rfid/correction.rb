# A staff correction: a named person, a reason and a time, attached to the
# immutable record it applies to. Corrections are the only way a historical
# adjudication changes, and they never edit the raw reading.
#
#   manual_exit    — closes one open visit; names its entry observation.
#   station_change — a staff-verified role/UID-rule change; names the station.
module Rfid
  class Correction < ApplicationRecord
    self.table_name = 'rfid_corrections'

    KINDS = %w[manual_exit station_change].freeze

    belongs_to :event
    belongs_to :actor, class_name: 'User', optional: true
    belongs_to :entry_observation, class_name: 'Rfid::Observation', optional: true
    belongs_to :station, class_name: 'Rfid::Station', optional: true

    validates :kind, inclusion: { in: KINDS }
    validates :reason, presence: true
    validate :target_matches_kind

    private

    def target_matches_kind
      if kind == 'station_change'
        errors.add(:station, 'is required') if station.nil?
      else
        errors.add(:entry_observation, 'is required') if entry_observation.nil?
        errors.add(:exit_at, 'is required') if exit_at.nil?
      end
    end
  end
end
