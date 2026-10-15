# One physical RfiDex station (a desk PC or a gate reader), identified by the
# opaque `X-RfiDex-Station` header the app sends. The station key is never a
# credential: it is scoped to the event the API key belongs to.
module Rfid
  class Station < ApplicationRecord
    self.table_name = 'rfid_stations'

    KINDS = %w[desk gate].freeze
    ROLES = %w[entry exit].freeze
    UID_RULES = %w[as_is reversed].freeze

    belongs_to :event

    validates :station_key, presence: true, length: { maximum: 128 },
                            format: { with: /\A[\x20-\x7E]+\z/,
                                      message: 'must be 1-128 printable ASCII characters' },
                            uniqueness: { scope: :event_id }
    validates :kind, inclusion: { in: KINDS }
    validates :role, inclusion: { in: ROLES }, allow_nil: true
    validates :uid_rule, inclusion: { in: UID_RULES }
    validates :name, length: { maximum: 255 }, allow_nil: true
  end
end
