class PublicExhibitorRegistrationToken
  PURPOSE = :public_exhibitor_new_registration
  TTL = 2.hours

  Access = Data.define(:event_id, :normalized_email) do
    def active? = true
  end

  def self.issue(event:, email:)
    verifier.generate(
      { 'event_id' => event.id, 'email' => PublicExhibitorAccessSession.normalize_email(email) },
      purpose: PURPOSE, expires_in: TTL
    )
  end

  def self.verify(token:, event:)
    payload = verifier.verify(token, purpose: PURPOSE)
    return unless payload['event_id'] == event.id

    Access.new(event_id: event.id, normalized_email: payload['email'])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
  private_class_method :verifier
end
