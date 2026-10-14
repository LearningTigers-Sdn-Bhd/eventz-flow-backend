class BusinessHostInviteToken
  PURPOSE = :business_host_invite
  KIND = 'host_invite'.freeze
  TTL = 30.days

  Access = Data.define(:event_id, :business_matching_event_id)

  # The "token" is a short code (ShortLink); one active link per session.
  def self.find(event_id:, business_matching_event_id:)
    ShortLink.find_for(kind: KIND, event_id: event_id, payload: payload_for(business_matching_event_id))&.code
  end

  def self.issue(event_id:, business_matching_event_id:)
    ShortLink.fetch(kind: KIND, event_id: event_id, ttl: TTL, payload: payload_for(business_matching_event_id)).code
  end

  def self.verify(token)
    link = ShortLink.lookup(token, kind: KIND)
    if link
      return Access.new(event_id: link.event_id.to_s, business_matching_event_id: link.payload['business_matching_event_id'])
    end

    verify_legacy(token)
  end

  def self.payload_for(business_matching_event_id)
    { 'business_matching_event_id' => business_matching_event_id.to_s }
  end
  private_class_method :payload_for

  # ponytail: signed tokens from links sent before short codes; delete after 30 days.
  def self.verify_legacy(token)
    payload = verifier.verify(token, purpose: PURPOSE)
    Access.new(event_id: payload['event_id'], business_matching_event_id: payload['business_matching_event_id'])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
  private_class_method :verify_legacy

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
  private_class_method :verifier
end
