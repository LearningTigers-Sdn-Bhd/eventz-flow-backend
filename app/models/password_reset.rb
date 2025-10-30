class PasswordReset < ApplicationRecord
  belongs_to :user

  EXPIRY_MINUTES = 30

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }

  def self.issue_for!(user)
    raw_token = SecureRandom.urlsafe_base64(32)
    digest = BCrypt::Password.create(raw_token)

    # Revoke existing active tokens for this user (optional but safer)
    where(user_id: user.id, revoked_at: nil).update_all(revoked_at: Time.current)

    create!(
      user: user,
      token_digest: digest,
      expires_at: EXPIRY_MINUTES.minutes.from_now
    )

    raw_token
  end

  def usable?
    revoked_at.nil? && expires_at.future?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def self.find_valid_by_token(raw_token)
    # We cannot query by token directly since it's hashed; search recent and verify
    recent = where('created_at > ?', 2.days.ago).order(created_at: :desc)
    recent.find do |record|
      begin
        BCrypt::Password.new(record.token_digest) == raw_token
      rescue BCrypt::Errors::InvalidHash
        false
      end
    end
  end
end
