class TicketApplication < ApplicationRecord
  belongs_to :ticket
  belongs_to :registration_form
  belongs_to :reviewed_by, class_name: 'User', optional: true

  enum :review_status, { pending_review: 0, approved: 1, rejected: 2 }
  enum :rsvp_status, { not_sent: 0, sent: 1, confirmed: 2, declined: 3, expired: 4 }

  validates :ticket_id, uniqueness: true
  validates :review_status, presence: true
  validates :rsvp_status, presence: true
  validates :rsvp_token_digest, uniqueness: true, allow_nil: true

  def assign_rsvp_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(rsvp_token_digest: self.class.digest_token(raw_token))
    raw_token
  end

  def matches_rsvp_token?(raw_token)
    return false if raw_token.blank? || rsvp_token_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      rsvp_token_digest,
      self.class.digest_token(raw_token)
    )
  end

  def expired?
    rsvp_expires_at.present? && rsvp_expires_at < Time.current
  end

  def self.digest_token(raw_token)
    OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, raw_token.to_s)
  end
end
