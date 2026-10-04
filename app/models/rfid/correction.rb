# A staff correction: a named person, a reason and a time, attached to the
# immutable record it applies to. Corrections are the only way a historical
# adjudication changes, and they never edit the raw reading.
#
#   manual_exit    — closes one open visit; names its entry observation.
#   station_change — a staff-verified role/UID-rule change; names the station.
#   manual_entry   — staff add an entry the gate never recorded (gate down,
#                    sticker unread); names the guest, entry in `details`. With
#                    an exit it is a closed visit; without, the next real exit
#                    closes it.
#   cert_override / cert_override_revoked — staff waive (or restore) the session
#                    attendance rule for one guest; the latest one wins.
module Rfid
  class Correction < ApplicationRecord
    self.table_name = 'rfid_corrections'

    KINDS = %w[manual_exit station_change manual_entry cert_override cert_override_revoked].freeze

    belongs_to :event
    belongs_to :actor, class_name: 'User', optional: true
    belongs_to :entry_observation, class_name: 'Rfid::Observation', optional: true
    belongs_to :station, class_name: 'Rfid::Station', optional: true
    belongs_to :ticket, optional: true

    validates :kind, inclusion: { in: KINDS }
    validates :reason, presence: true
    validate :target_matches_kind

    def entry_at
      Time.iso8601(details['entry_at'].to_s)
    rescue ArgumentError
      nil
    end

    private

    def target_matches_kind
      if kind == 'station_change'
        errors.add(:station, 'is required') if station.nil?
      elsif kind == 'manual_entry'
        errors.add(:ticket, 'is required') if ticket.nil?
        errors.add(:base, 'entry_at is required') if entry_at.nil?
        errors.add(:base, 'entry must be before exit') if entry_at && exit_at && entry_at >= exit_at
      elsif kind.in?(%w[cert_override cert_override_revoked])
        errors.add(:ticket, 'is required') if ticket.nil?
      else
        errors.add(:entry_observation, 'is required') if entry_observation.nil?
        errors.add(:exit_at, 'is required') if exit_at.nil?
      end
    end
  end
end
