require "net/http"
require "json"

module PeopleCounter
  # Read-only client for the external people-counter service (bearer API key).
  #
  # An event's own connection (PeopleCounterConnection, set by an org owner) is
  # used first; PEOPLE_COUNTER_URL / PEOPLE_COUNTER_API_TOKEN are the fallback.
  class Client
    class Error < StandardError; end

    # The service answered but refused the key (wrong, expired or revoked).
    class Unauthorized < Error; end

    TIMEOUT = 5

    # Server-side fallback, trusted config: not SSRF-guarded.
    def self.default
      new(base_url: ENV["PEOPLE_COUNTER_URL"], token: ENV["PEOPLE_COUNTER_API_TOKEN"])
    end

    def self.for_event(event)
      connection = event.people_counter_connection
      # persisted?: an unsaved connection (e.g. one being built in a form) is not a configuration
      return default unless connection&.persisted?

      new(base_url: connection.base_url, token: connection.api_key, guard: guard?)
    end

    def self.configured_for?(event)
      event.people_counter_connection&.persisted? ||
        (ENV["PEOPLE_COUNTER_URL"].present? && ENV["PEOPLE_COUNTER_API_TOKEN"].present?)
    end

    # User-entered URLs must not reach private or local networks. Development is
    # exempt so a counter service running on localhost can be tried.
    def self.guard?
      !Rails.env.development?
    end

    def initialize(base_url:, token:, guard: false)
      raise Error, "People counter is not configured" if base_url.blank? || token.blank?

      @base = parse(base_url)
      @token = token
      @guard = guard
    end

    # [{ "id", "name", "capacity", "today" => { "in", "out", "occupancy" } }]
    def venues
      get("/api/v1/venues")
    end

    # { "in", "out", "occupancy" } for the venue's current day, or for the
    # whole-day window from..to (inclusive) when both dates are given.
    def venue_totals(venue_id, from: nil, to: nil)
      get("/api/v1/venues/#{Integer(venue_id)}/totals", range_query(from, to))
    end

    # [{ "bucket" => ISO8601, "in", "out" }] summed across the venue's counters.
    def venue_series(venue_id, from:, to:, bucket: 60)
      get("/api/v1/venues/#{Integer(venue_id)}/series", range_query(from, to).merge(bucket: bucket))
    end

    private

    def parse(base_url)
      uri = URI(base_url.chomp("/"))
      raise Error, "People counter URL must start with http:// or https://" unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri
    rescue URI::InvalidURIError
      raise Error, "People counter URL is not valid"
    end

    def range_query(from, to)
      from && to ? { from: from.to_date.iso8601, to: to.to_date.iso8601 } : {}
    end

    def get(path, query = {})
      uri = @base.dup
      uri.path = path
      uri.query = URI.encode_www_form(query) if query.any?
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", ipaddr: safe_address(uri),
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
      raise Unauthorized, "People counter rejected the key" if [401, 403].include?(response.code.to_i)
      raise Error, "People counter #{path} failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("data")
    rescue JSON::ParserError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Error, "People counter #{path} unreachable: #{e.class}"
    end

    # Pins the connection to an address that passed the SSRF check, so DNS
    # can't change between the check and the connect. nil = no pinning.
    def safe_address(uri)
      return nil unless @guard

      AiIntegrations::NetworkGuard.pick_safe_address(uri.host)
    rescue AiIntegrations::NetworkGuard::Blocked => e
      raise Error, e.message
    end
  end
end
