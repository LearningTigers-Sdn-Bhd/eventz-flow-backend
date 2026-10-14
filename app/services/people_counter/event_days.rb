module PeopleCounter
  # The event day by day: arrivals, departures and the peak crowd for each day
  # up to today, event-wide and per hall. Each day is one EventAnalytics read
  # (which caches itself), so a day here always matches that day's Trends view.
  # Days still to come are left out: there is nothing to count yet.
  class EventDays
    CACHE_TTL = 60.seconds
    MAX_DAYS = 31

    def initialize(event, client: nil, today: Time.zone.today)
      @event = event
      @client = client
      @today = today.iso8601
    end

    def call
      Rails.cache.fetch("people_counter/days/#{@event.id}", expires_in: CACHE_TTL) { build }
    end

    private

    def build
      listing = analytics(nil)
      return { configured: false, days: [] } unless listing.configured?

      days = listing.days.select { |day| day <= @today }.first(MAX_DAYS)
      { configured: true, days: days.map { |day| summarize(analytics(day).call) } }
    end

    def analytics(day)
      EventAnalytics.new(@event, date: day, bucket: 60, client: @client)
    end

    def summarize(data)
      { date: data[:date] }.merge(figures(data[:event])).merge(
        halls: data[:halls].map do |hall|
          { id: hall[:id], name: hall[:name], floor: hall[:floor], status: hall[:status] }.merge(figures(hall))
        end
      )
    end

    # Totals and peaks for one scope's hourly points. Peaks are nil when nothing was counted.
    def figures(scope)
      stats = scope[:stats]
      {
        entries: scope[:points].sum { |p| p[:in] },
        exits: scope[:points].sum { |p| p[:out] },
        peak: stats && stats[:peak],
        busiest_entry_hour: stats && stats[:busiest_entry_hour],
        closing: scope[:points].last&.dig(:occupancy)
      }
    end
  end
end
