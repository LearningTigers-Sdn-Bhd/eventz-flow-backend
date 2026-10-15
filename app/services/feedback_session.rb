# frozen_string_literal: true

# Signed, expiring proof that someone opened an active feedback form. It lets
# them submit after the organizer closes the form mid-fill.
module FeedbackSession
  PURPOSE = :feedback_session
  TTL = 12.hours

  def self.issue(form)
    verifier.generate(form.id, expires_in: TTL)
  end

  def self.valid?(token, form)
    return false if token.blank?

    verifier.verified(token) == form.id
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
end
