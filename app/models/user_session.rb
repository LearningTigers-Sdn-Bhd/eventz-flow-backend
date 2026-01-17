class UserSession < ApplicationRecord
  belongs_to :user

  validates :jti, presence: true, uniqueness: true
  validates :refresh_token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked: false).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def active?
    !revoked? && !expired?
  end

  def expired?
    expires_at <= Time.current
  end

  def revoke!
    update!(revoked: true)
  end

  def touch!
    update!(last_used_at: Time.current)
  end
end
