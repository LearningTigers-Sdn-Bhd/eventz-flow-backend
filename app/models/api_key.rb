class ApiKey < ApplicationRecord
  # Associations (assuming you have a belongs_to :user)
  belongs_to :user 

  # Validations (optional, but recommended)
  validates :key_hash, presence: true, uniqueness: true
  
  # Scopes
  scope :active, -> { where(is_active: true) }

  # --- API Key Generation and Creation ---

  # Creates a new ApiKey record and returns the RAW (unhashed) key string.
  # This is the key the client will use for API calls.
  #
  # NOTE: This method relies on AuthenticationService to generate and hash the token.
  # Make sure AuthenticationService.generate_secure_token and AuthenticationService.hash_token exist.
  def self.create_key_for_user(user)
    # 1. Generate the raw, secure key string
    raw_key = AuthenticationService.generate_secure_token

    # 2. Hash the key for secure storage in the database
    hashed_key = AuthenticationService.hash_token(raw_key)

    # 3. Create the record
    create!(
      user: user,
      key_hash: hashed_key,
      is_active: true
    )

    # 4. Return the RAW key string to the user (or test suite)
    raw_key
  end
  
  # --- Authentication Verification Method (used in controllers) ---

  # Attempts to find an active API Key by the raw key string provided by the client.
  def self.authenticate_by_key(raw_key)
    return nil unless raw_key.present?

    # Hash the incoming raw key
    hashed_key = AuthenticationService.hash_token(raw_key)

    # Find the active key record
    key = active.find_by(key_hash: hashed_key)

    if key
      # Update last_used_at timestamp on successful authentication
      key.update!(last_used_at: Time.current)
      return key.user
    end

    nil
  end
end