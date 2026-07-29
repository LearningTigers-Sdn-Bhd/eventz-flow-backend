require 'digest'
require 'securerandom'

class PublicExhibitorAccessSession < ApplicationRecord
  class InvalidToken < StandardError; end

  CHALLENGE_TTL = 15.minutes
  SESSION_TTL = 24.hours

  belongs_to :event

  validates :normalized_email, :challenge_digest, :challenge_expires_at, presence: true
  validates :challenge_digest, uniqueness: true
  validates :session_digest, uniqueness: true, allow_nil: true

  def self.issue_challenge!(event:, email:)
    token = SecureRandom.urlsafe_base64(32)
    record = create!(
      event: event,
      normalized_email: normalize_email(email),
      challenge_digest: digest(token),
      challenge_expires_at: CHALLENGE_TTL.from_now
    )
    [record, token]
  end

  def self.authenticate(event:, token:)
    return if token.blank?

    record = find_by(event: event, session_digest: digest(token))
    return unless record&.active?

    record.update_column(:last_used_at, Time.current)
    record
  end

  def self.issue_session!(event:, email:)
    session_token = SecureRandom.urlsafe_base64(32)
    record = create!(event: event, normalized_email: normalize_email(email),
      challenge_digest: digest(SecureRandom.urlsafe_base64(32)), challenge_expires_at: Time.current,
      session_digest: digest(session_token), expires_at: SESSION_TTL.from_now)
    [record, session_token]
  end

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def exchange_challenge!(token)
    session_token = nil
    with_lock do
      valid = challenge_consumed_at.nil? && challenge_expires_at.future? &&
        ActiveSupport::SecurityUtils.secure_compare(challenge_digest, self.class.digest(token))
      raise InvalidToken unless valid

      session_token = SecureRandom.urlsafe_base64(32)
      update!(challenge_consumed_at: Time.current, session_digest: self.class.digest(session_token),
              expires_at: SESSION_TTL.from_now)
    end
    session_token
  end

  def active?
    session_digest.present? && expires_at&.future? && revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
