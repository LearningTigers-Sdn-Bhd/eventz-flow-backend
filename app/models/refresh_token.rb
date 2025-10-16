class RefreshToken < ApplicationRecord
  # Ensure the token belongs to a User
  # The presence of the user is mandatory for a refresh token to be valid
  belongs_to :user, inverse_of: :refresh_tokens

  # Validation to ensure a token_hash exists
  validates :token_hash, presence: true, uniqueness: true

  # Scope for quickly finding active tokens (optional but helpful)
  scope :active, -> { where("expires_at > ? AND revoked_at IS NULL", Time.current) }
  
  # Instance method to check if the token is still valid
  def active?
    expires_at > Time.current && revoked_at.nil?
  end
  
  def revoke!
    self.update!(revoked_at: Time.current)
  end
end