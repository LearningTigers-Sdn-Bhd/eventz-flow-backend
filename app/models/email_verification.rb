# app/models/email_verification.rb
require 'bcrypt'
require 'securerandom'

class EmailVerification < ApplicationRecord
  # --- Attributes & Dependencies ---
  belongs_to :user

  # Used to hold the raw code only during creation (not saved to DB)
  attr_accessor :raw_code

  # --- Callbacks ---
  before_validation :generate_code_and_hash, on: :create
  before_validation :set_expiration, on: :create

  validates :hashed_code, presence: true
  validates :user_id, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil) }
  scope :non_expired, -> { where('expires_at > ?', Time.current) }
  scope :usable, -> { active.non_expired }

  # =========================================================================
  # 1. GENERATION METHOD (Secure Creation)
  # =========================================================================

  # Creates a new EmailVerification record and returns the RAW (unhashed) code string.
  def self.create_for_user(user)
    # Revoke any existing active verification codes for this user
    EmailVerification.where(user_id: user.id)
                    .active
                    .update_all(revoked_at: Time.current)

    # Create new verification
    verification = user.email_verifications.new
    verification.save!

    # Return the RAW code string (only available once)
    verification.raw_code
  end

  # =========================================================================
  # 2. AUTHENTICATION METHOD (Secure Verification)
  # =========================================================================

  # Attempts to authenticate a raw code by comparing it to the stored hash.
  # This uses the secure BCrypt comparison method.
  def self.verify_code(user, raw_code)
    return false unless raw_code.present?

    # Find all active, non-expired verifications for this user
    verification = EmailVerification.where(user_id: user.id)
                                    .usable
                                    .find_each do |verification_record|
      # BCrypt handles the unsalting and comparison securely
      if BCrypt::Password.new(verification_record.hashed_code) == raw_code
        # Revoke this verification code (one-time use)
        verification_record.update!(revoked_at: Time.current)

        # Mark user's email as verified
        user.update!(email_verified_at: Time.current)

        return true
      end
    end

    false
  rescue BCrypt::Errors::InvalidHash, ArgumentError
    # Handle cases where the stored hash is malformed
    false
  end

  # Check if verification is expired
  def expired?
    expires_at < Time.current
  end

  # Check if verification is revoked
  def revoked?
    revoked_at.present?
  end

  private

  # Generates a random 6-digit code and computes its BCrypt hash (used on create)
  def generate_code_and_hash
    # Ensure this only runs if the code is not already set
    unless hashed_code.present?
      # Generate a 6-digit code
      self.raw_code = format('%06d', SecureRandom.random_number(1_000_000))
      # Hash the code using BCrypt for secure, salted storage
      self.hashed_code = BCrypt::Password.create(raw_code)
    end
  end

  # Set expiration time (15 minutes from now, similar to JWT)
  def set_expiration
    self.expires_at ||= 15.minutes.from_now
  end
end
