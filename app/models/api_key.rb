require 'bcrypt'
require 'securerandom'

class ApiKey < ApplicationRecord
  SCOPES = %w[read_only check_in read_write rfid].freeze
  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze
  CHECK_IN_PATH_RE = %r{/(check_in|unscan)(/|\z)}.freeze

  # --- RFID device keys ---
  # RfiDex sends the raw key in `Authorization`. A key minted for RfiDex is
  # `rfd_<16 lowercase hex>_<64 lowercase hex>`: the first 20 characters are
  # stored (and indexed) as `key_prefix`, while only a bcrypt hash of the whole
  # key is kept. The prefix is a lookup hint, never a credential — a candidate
  # still has to bcrypt-verify the full key.
  RFID_SCOPE = 'rfid'
  RFID_KEY_NAMESPACE = 'rfd_'
  RFID_PREFIX_LENGTH = 20
  RFID_KEY_RE = /\Arfd_[0-9a-f]{16}_[0-9a-f]{64}\z/.freeze

  # The RfiDex device API, method and path exactly as `rfidex-core` calls it.
  # An `rfid` key may reach these seven pairs and nothing else, in any scope
  # combination the other scopes would allow.
  RFID_ROUTES = [
    'POST /v1/rfid/stations/heartbeat',
    'GET /v1/rfid/cache',
    'GET /v1/rfid/tickets/search',
    'POST /v1/rfid/desk_scans',
    'POST /v1/rfid/bindings',
    'GET /v1/rfid/bindings/lookup',
    'POST /v1/rfid/observations'
  ].freeze

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
  #   rfid       — exactly the seven RfiDex device routes below, nothing else.
  def allows_method?(http_method, path = nil)
    method = http_method.to_s.upcase
    case scope
    when 'read_only'  then !WRITE_METHODS.include?(method)
    when 'check_in'
      return true unless WRITE_METHODS.include?(method)
      return true if method == 'POST'
      method == 'PATCH' && path.to_s.match?(CHECK_IN_PATH_RE)
    when 'read_write' then true
    when RFID_SCOPE   then RFID_ROUTES.include?("#{method} #{path.to_s.chomp('/')}")
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
  #
  # A recognisable `rfd_` key is matched by its indexed prefix and then bcrypt
  # verified. It never falls back to the legacy scan, so a mistyped or revoked
  # device key cannot accidentally match some other key. Anything else is a
  # legacy key (NULL prefix) and is scanned exactly as before.
  def self.authenticate_by_key(raw_key)
    return nil unless raw_key.present?
    return authenticate_prefixed(raw_key) if raw_key.start_with?(RFID_KEY_NAMESPACE)

    ApiKey.active.where(key_prefix: nil).find_each do |key_record|
      return touch_and_return(key_record) if verify(key_record, raw_key)
    end

    nil
  rescue BCrypt::Errors::InvalidHash, ArgumentError
    nil
  end

  def self.authenticate_prefixed(raw_key)
    return nil unless raw_key.match?(RFID_KEY_RE)
    return nil unless key_record = ApiKey.active.find_by(key_prefix: raw_key[0, RFID_PREFIX_LENGTH])
    return nil unless verify(key_record, raw_key)

    touch_and_return(key_record)
  end
  private_class_method :authenticate_prefixed

  # `last_used_at` moves only after the bcrypt comparison matched.
  def self.touch_and_return(key_record)
    key_record.update!(last_used_at: Time.current)
    key_record
  end
  private_class_method :touch_and_return

  def self.verify(key_record, raw_key)
    BCrypt::Password.new(key_record.key_hash) == raw_key
  end
  private_class_method :verify

  def revoke!
    update(is_active: false)
  end

  private

  def generate_key_and_hash
    return if key_hash.present?

    self.raw_key = if scope == RFID_SCOPE
                     self.key_prefix = "rfd_#{SecureRandom.hex(8)}"
                     "#{key_prefix}_#{SecureRandom.hex(32)}"
                   else
                     SecureRandom.hex(32)
                   end
    self.key_hash = BCrypt::Password.create(raw_key)
  end

  def event_allows_api_access
    errors.add(:event, 'does not have API access enabled') unless event&.use_api_access?
  end
end
