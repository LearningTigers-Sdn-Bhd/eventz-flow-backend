# Vendor invite link: a short code (ShortLink) that resolves to the same
# payload the old signed token carried ({event_id, organizer_id, group_id, exp}).
class VendorInviteToken
  KIND = 'vendor_invite'.freeze
  TTL = 7.days

  def self.issue(event_id:, organizer_id:, group_id: nil)
    payload = { 'organizer_id' => organizer_id.to_i }
    payload['group_id'] = group_id.to_i if group_id.present?
    ShortLink.fetch(kind: KIND, event_id: event_id, ttl: TTL, payload: payload)
  end

  # Returns the payload hash; raises InvalidSignature if unknown/expired, so
  # callers keep their existing rescue.
  def self.verify(token)
    link = ShortLink.lookup(token, kind: KIND)
    return link.payload.merge('event_id' => link.event_id, 'exp' => link.expires_at.to_i).with_indifferent_access if link

    # ponytail: signed tokens from links sent before short codes; delete after 7 days.
    Rails.application.message_verifier(KIND).verify(token)
  end
end
