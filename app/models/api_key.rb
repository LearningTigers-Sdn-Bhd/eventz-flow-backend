require 'bcrypt'
require 'securerandom'

class ApiKey < ApplicationRecord
  # --- Attributes & Dependencies ---
  belongs_to :user
  belongs_to :event, optional: true

  # Used to hold the raw key only during creation (not saved to DB)
  attr_accessor :raw_key

  # --- Callbacks & Scopes ---
  before_validation :generate_key_and_hash, on: :create

  validates :key_hash, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :name, length: { maximum: 255 }

  validate :event_allows_api_access, if: -> { event_id.present? }

  scope :active, -> { where(is_active: true) }

  # =========================================================================
  # 1. GENERATION METHOD (Secure Creation)
  # =========================================================================

  def self.create_key_for_user(user)
    key = user.api_keys.new
    key.save!
    key.raw_key
  end

  # =========================================================================
  # 2. AUTHENTICATION METHOD (Secure Verification)
  # =========================================================================

  # Returns the ApiKey record (not just user) so callers can check event_id.
  def self.authenticate_by_key(raw_key)
    return nil unless raw_key.present?

    ApiKey.active.find_each do |key_record|
      if BCrypt::Password.new(key_record.key_hash) == raw_key
        key_record.update!(last_used_at: Time.current)
        return key_record
      end
    end

    nil
  rescue BCrypt::Errors::InvalidHash, ArgumentError
    nil
  end

  def revoke!
    update(is_active: false)
  end

  private

  def generate_key_and_hash
    unless key_hash.present?
      self.raw_key = SecureRandom.hex(32)
      self.key_hash = BCrypt::Password.create(raw_key)
    end
  end

  def event_allows_api_access
    errors.add(:event, 'does not have API access enabled') unless event&.use_api_access?
  end
end
