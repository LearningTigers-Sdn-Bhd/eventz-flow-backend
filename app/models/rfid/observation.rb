# One raw gate reading, stored once per (station, delivery_id) with the reply
# it was first given. `original_response` is immutable evidence: later
# re-adjudication (a late binding, a staff correction) updates `outcome` and
# `anomalies`, never the saved reply.
module Rfid
  class Observation < ApplicationRecord
    self.table_name = 'rfid_observations'

    ROLES = Rfid::Station::ROLES
    PROTOCOLS = Rfid::Binding::PROTOCOLS
    OUTCOMES = %w[
      accepted unknown_tag revoked_tag wrong_event ticket_invalid not_checked_in
      possible_duplicate
    ].freeze

    belongs_to :event
    belongs_to :station, class_name: 'Rfid::Station'
    belongs_to :ticket, optional: true

    before_validation :stamp_recorded_at, on: :create

    validates :delivery_id, presence: true
    validates :role, inclusion: { in: ROLES }
    validates :protocol, inclusion: { in: PROTOCOLS }
    validates :uid_raw_hex, presence: true
    validates :tag_key, presence: true
    validates :captured_at, presence: true
    validates :recorded_at, presence: true
    validates :outcome, inclusion: { in: OUTCOMES }
    validates :request_digest, presence: true

    # The vendor's raw direction byte, kept as evidence. Never authoritative:
    # a station's configured role wins, and a disagreement is only flagged.
    def device_direction_raw
      device_metadata['device_direction_raw']
    end

    private

    def stamp_recorded_at
      self.recorded_at ||= Time.current
    end
  end
end
