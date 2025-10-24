# app/models/api_key.rb
require 'bcrypt'
require 'securerandom'

class ApiKey < ApplicationRecord
  # --- Attributes & Dependencies ---
  belongs_to :user
  
  # Used to hold the raw key only during creation (not saved to DB)
  attr_accessor :raw_key 
  
  # --- Callbacks & Scopes ---
  before_validation :generate_key_and_hash, on: :create
  
  validates :key_hash, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :name, length: { maximum: 255 }

  # Add this if need to restrict one active API key per user (database level enforcement)
  # validates :user_id, uniqueness: { 
  #   scope: :is_active, 
  #   conditions: -> { where(is_active: true) },
  #   message: "already has an active API key"
  # }, if: :is_active?
  
  scope :active, -> { where(is_active: true) }

  # =========================================================================
  # 1. GENERATION METHOD (Secure Creation)
  # =========================================================================
  
  # Creates a new ApiKey record and returns the RAW (unhashed) key string.
  def self.create_key_for_user(user)
    key = user.api_keys.new
    
    # We rely on the before_validation callback to populate key.raw_key and key.key_hash
    key.save!

    # Return the RAW key string (only available once)
    key.raw_key
  end
  
  # =========================================================================
  # 2. AUTHENTICATION METHOD (Secure Verification)
  # =========================================================================

  # Attempts to authenticate a raw key by comparing it to the stored hash.
  # This uses the secure BCrypt comparison method.
  def self.authenticate_by_key(raw_key)
    return nil unless raw_key.present?

    # Since we cannot lookup by the raw key, we must check ALL active keys.
    # We find a key that is the correct length and check against its hash.
    # A common optimization is to use the first N characters as a lookup index,
    # but for simplicity, we iterate over all active keys for the comparison.
    
    key = ApiKey.active.find_each do |key_record|
      # BCrypt handles the unsalting and comparison securely
      if BCrypt::Password.new(key_record.key_hash) == raw_key
        # Update last_used_at timestamp on successful authentication
        key_record.update!(last_used_at: Time.current)
        return key_record.user
      end
    end
    
    nil
  rescue BCrypt::Errors::InvalidHash, ArgumentError
    # Handle cases where the stored hash is malformed
    nil
  end

  # Revoke method (soft delete)
  def revoke!
    update(is_active: false)
  end
  
  private
  
  # Generates a random raw key and computes its BCrypt hash (used on create)
  def generate_key_and_hash
    # Ensure this only runs if the key is not already set
    unless key_hash.present?
      # Generate a strong, random key
      self.raw_key = SecureRandom.hex(32) 
      # Hash the key using BCrypt for secure, salted storage
      self.key_hash = BCrypt::Password.create(raw_key)
    end
  end
end
