# Short, revocable code behind a shareable link (e.g. /invite/host/<code>).
# `kind` says what it is for; each route only accepts its own kind.
class ShortLink < ApplicationRecord
  belongs_to :event

  scope :active, -> { where('expires_at > ?', Time.current) }

  before_validation { self.code ||= SecureRandom.alphanumeric(8) }

  # Active link for exactly this event/kind/payload, if any.
  def self.find_for(kind:, event_id:, payload: {})
    active.where(kind: kind, event_id: event_id).find_by('payload = ?::jsonb', payload.to_json)
  end

  # Reuse the active link, or create one that lives for `ttl`.
  def self.fetch(kind:, event_id:, ttl:, payload: {})
    find_for(kind: kind, event_id: event_id, payload: payload) ||
      create!(kind: kind, event_id: event_id, payload: payload, expires_at: ttl.from_now)
  end

  def self.lookup(code, kind:)
    active.find_by(code: code.to_s, kind: kind)
  end
end
