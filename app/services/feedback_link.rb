# frozen_string_literal: true

# Personal feedback links. Ticket holders carry their ticket public_id; exhibitor
# companies carry a signed id (no login, tamper-proof, tied to the company).
module FeedbackLink
  def self.base(event)
    "#{frontend(event)}/events/#{event.slug.presence || event.id}/feedback"
  end

  def self.ticket(event, ticket)
    "#{base(event)}?ticket=#{ticket.public_id}"
  end

  # Short code for sharing by hand (WhatsApp etc). Resolves via
  # GET /v1/public/feedback_links/:code; one active link per company.
  SHORT_KIND = 'exhibitor_feedback'.freeze
  SHORT_TTL = 180.days

  def self.exhibitor_short(event, exhibitor)
    link = ShortLink.fetch(kind: SHORT_KIND, event_id: event.id, ttl: SHORT_TTL,
                           payload: { 'exhibitor_id' => exhibitor.id })
    "#{frontend(event)}/feedback/#{link.code}"
  end

  # The signed exhibitor token behind a short code, or nil when unknown/expired.
  def self.resolve_short(code)
    link = ShortLink.lookup(code, kind: SHORT_KIND)
    exhibitor = link && Exhibitor.find_by(id: link.payload['exhibitor_id'], event_id: link.event_id)
    return unless exhibitor

    { event_slug: link.event.slug.presence || link.event.id.to_s, exhibitor_token: exhibitor.signed_id(purpose: :feedback) }
  end

  def self.frontend(_event = nil)
    ENV.fetch('FRONTEND_URL', ENV.fetch('APP_FRONTEND_URL', 'http://localhost:3001')).to_s.chomp('/')
  end

  def self.exhibitor(event, exhibitor)
    "#{base(event)}?exhibitor=#{exhibitor.signed_id(purpose: :feedback)}"
  end
end
