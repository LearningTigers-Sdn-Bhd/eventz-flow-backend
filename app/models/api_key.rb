require 'bcrypt'
require 'securerandom'

class ApiKey < ApplicationRecord
  SCOPES = %w[read_only check_in read_write].freeze
  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze
  CHECK_IN_PATH_RE = %r{/(check_in|unscan)(/|\z)}.freeze

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
  validates :scope, presence: true, inclusion: { in: SCOPES }

  validate :event_allows_api_access, if: -> { event_id.present? }

  scope :active, -> { where(is_active: true) }

  # Whether this key is permitted to perform an HTTP request with the given
  # method and path. Scopes:
  #   read_only  — GET/HEAD only.
  #   check_in   — read + POST anywhere + PATCH on check-in/unscan paths only
  #                (the scan/check_in routes are PATCH; kiosk keys must reach
  #                them without unlocking arbitrary PATCH writes).
  #   read_write — full CRUD.
  def allows_method?(http_method, path = nil)
    method = http_method.to_s.upcase
    case scope
    when 'read_only'  then !WRITE_METHODS.include?(method)
    when 'check_in'
      return true unless WRITE_METHODS.include?(method)
      return true if method == 'POST'
      method == 'PATCH' && path.to_s.match?(CHECK_IN_PATH_RE)
    when 'read_write' then true
    else false
    end
  end

  # =========================================================================
  # 1. GENERATION METHOD (Secure Creation)
  # =========================================================================

  def self.create_key_for_user(user, scope: 'read_only')
    key = user.api_keys.new(scope: scope)
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
