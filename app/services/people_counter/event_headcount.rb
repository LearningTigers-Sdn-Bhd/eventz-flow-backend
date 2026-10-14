module PeopleCounter
  # Rolls the counter service's numbers up from hall to level (floor) to event.
  #
  # Per hall: live figures come from the venue list (one request for all halls),
  # event-wide in/out from a whole-day window over the event's start..end dates.
  # A hall that can't be read degrades on its own (status), never the whole page.
  #
  # Hall status: "ok" | "unlinked" (no counter venue set) | "not_found" (venue
  # gone on the counter service) | "unavailable" (counter service unreachable).
  class EventHeadcount
    CACHE_TTL = 15.seconds
    SUM_KEYS = %i[inside_now capacity in_today out_today in_event out_event].freeze

    def initialize(event, client: nil)
      @event = event
      @client = client
    end

    def self.cache_key(event_id)
      "people_counter/headcount/#{event_id}"
    end

    def call
      Rails.cache.fetch(self.class.cache_key(@event.id), expires_in: CACHE_TTL) { build }
    end

    private

    # The event's own connection, else the server-wide fallback. Built lazily:
    # a missing config raises Client::Error where it is rescued (halls become
    # "unavailable") instead of failing the whole request.
    def client
      @client ||= Client.for_event(@event)
    end

    def configured?
      @client.present? || Client.configured_for?(@event)
    end

    def build
      halls = @event.event_halls.ordered.to_a
      venues = live_venues(halls)
      rows = halls.map { |hall| hall_row(hall, venues) }

      {
        configured: configured?,
        event: rollup(rows),
        levels: rows.group_by { |r| r[:floor] }.map { |floor, group| { floor: floor }.merge(rollup(group)) },
        halls: rows,
        generated_at: Time.current.iso8601
      }
    end

    # { venue_id => venue hash }, or nil when the service can't be reached.
    def live_venues(halls)
      return {} if halls.none?(&:counter_venue_id)

      client.venues.index_by { |v| v["id"] }
    rescue Client::Error
      nil
    end

    def hall_row(hall, venues)
      row = { id: hall.id, name: hall.name, floor: hall.floor, status: "ok" }.merge(blank_figures)
      return row.merge(status: "unlinked") if hall.counter_venue_id.nil?
      return row.merge(status: "unavailable") if venues.nil?

      venue = venues[hall.counter_venue_id]
      return row.merge(status: "not_found") if venue.nil?

      today = venue["today"]
      row.merge(
        capacity: venue["capacity"], inside_now: today["occupancy"],
        in_today: today["in"], out_today: today["out"], **event_window(hall)
      )
    end

    def event_window(hall)
      return {} unless @event.start_date && @event.end_date

      totals = client.venue_totals(hall.counter_venue_id, from: @event.start_date, to: @event.end_date)
      { in_event: totals["in"], out_event: totals["out"] }
    rescue Client::Error
      {}
    end

    def blank_figures
      SUM_KEYS.index_with { nil }
    end

    # Sums only the halls that have a figure, so one missing hall doesn't zero the level.
    def rollup(rows)
      sums = SUM_KEYS.index_with do |key|
        values = rows.filter_map { |r| r[key] }
        values.sum if values.any?
      end
      sums.merge(halls: rows.size, halls_counted: rows.count { |r| r[:status] == "ok" })
    end
  end
end
