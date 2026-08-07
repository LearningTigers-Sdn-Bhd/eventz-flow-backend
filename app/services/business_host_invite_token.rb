class BusinessHostInviteToken
  PURPOSE = :business_host_invite
  TTL = 30.days

  Access = Data.define(:event_id, :business_matching_event_id)

  def self.issue(event_id:, business_matching_event_id:)
    verifier.generate(
      { 'event_id' => event_id.to_s, 'business_matching_event_id' => business_matching_event_id.to_s },
      purpose: PURPOSE, expires_in: TTL
    )
  end

  def self.verify(token)
    payload = verifier.verify(token, purpose: PURPOSE)
    Access.new(event_id: payload['event_id'], business_matching_event_id: payload['business_matching_event_id'])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
  private_class_method :verifier
end
