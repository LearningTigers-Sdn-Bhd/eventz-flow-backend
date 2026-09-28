# One sticker linked to one ticket. Rows are append-only: a replacement
# revokes the old row and inserts a new one, so history — and the historical
# validity window an observation is judged against — is never rewritten.
#
# The ticket is copied into snapshots because a hard ticket delete must not
# destroy the audit trail; the FK nullifies and the binding still answers.
module Rfid
  class Binding < ApplicationRecord
    self.table_name = 'rfid_bindings'

    PROTOCOLS = %w[iso15693 iso14443a iso18000_6c unknown].freeze
    MODES = %w[bind written].freeze

    belongs_to :event
    belongs_to :ticket, optional: true

    scope :active, -> { where(revoked_at: nil) }

    before_validation :stamp_recorded_at, on: :create

    validates :ticket_public_id, presence: true
    validates :uid_raw_hex, presence: true
    validates :tag_key, presence: true
    validates :protocol, inclusion: { in: PROTOCOLS }
    validates :mode, inclusion: { in: MODES }
    validates :captured_at, presence: true
    validates :recorded_at, presence: true
    validates :operation_id, presence: true

    def active?
      revoked_at.nil?
    end

    private

    def stamp_recorded_at
      self.recorded_at ||= Time.current
    end
  end
end
