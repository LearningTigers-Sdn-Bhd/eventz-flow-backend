# Where an event reads its people counts from: the counter service's URL and an
# API key created there. One per event; the key is encrypted at rest and never
# sent back to the browser (only key_prefix is).
class PeopleCounterConnection < ApplicationRecord
  KEY_PREFIX_LENGTH = 8

  # Note: assigning `event:` to a new connection also attaches it to the event
  # (automatic inverse), so "is it configured?" checks must use persisted?.
  belongs_to :event

  encrypts :api_key

  before_validation { self.base_url = base_url.to_s.strip.chomp("/") }

  validates :api_key, presence: true
  validates :base_url, presence: true, format: {
    with: URI::DEFAULT_PARSER.make_regexp(Rails.env.local? ? %w[http https] : %w[https]),
    message: Rails.env.local? ? "must be a valid URL" : "must be a valid HTTPS URL"
  }
  validates :event_id, uniqueness: true

  # Changing the connection must not show the previous service's cached numbers.
  after_commit { Rails.cache.delete(PeopleCounter::EventHeadcount.cache_key(event_id)) }

  def key_prefix
    api_key.to_s.first(KEY_PREFIX_LENGTH)
  end
end
