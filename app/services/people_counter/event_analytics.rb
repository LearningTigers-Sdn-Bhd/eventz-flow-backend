module PeopleCounter
  # One day of an event's counts over time, per hall, level and whole event.
  #
  # Always read from the counter service in 15-minute buckets; the requested
  # bucket (15 or 60) only changes how the points are shown. Occupancy is the
  # running In minus Out through the day, never below zero. Level and event
  # lines are the sum of their halls' lines, so the three always agree.
  #
  # Bucket strings are the counter's local clock ("2026-10-13T14:15:00"); they
  # are passed through untouched so no timezone conversion can shift them.
  class EventAnalytics
    CACHE_TTL = 30.seconds
    BUCKETS = [15, 60].freeze
    MAX_DAYS = 60

    attr_reader :date, :bucket, :days

    def initialize(event, date: nil, bucket: 60, client: nil)
      @event = event
      @client = client
      @days = event_days
      @date = pick_date(date)
      @bucket = BUCKETS.include?(bucket) ? bucket : 60
    end

    def call
      Rails.cache.fetch("people_counter/analytics/#{@event.id}/#{@date}/#{@bucket}", expires_in: CACHE_TTL) { build }
    end

    def configured?
      @client.present? || Client.configured_for?(@event)
    end

    private

    def event_days
      return [Time.zone.today.iso8601] unless @event.start_date && @event.end_date

      (@event.start_date.to_date..@event.end_date.to_date).first(MAX_DAYS).map(&:iso8601)
    end

    # The asked-for day if it is one of the event's days, else today, else the first day.
    def pick_date(requested)
      day = Date.iso8601(requested.to_s).iso8601
      return day if @days.include?(day)

      default_day
    rescue Date::Error
      default_day
    end

    def default_day
      today = Time.zone.today.iso8601
      @days.include?(today) ? today : @days.first
    end

    def client
      @client ||= Client.for_event(@event)
    end

    def build
      base = { date: @date, days: @days, bucket: @bucket, configured: configured?, generated_at: Time.current.iso8601 }
      return base.merge(event: { points: [], stats: nil }, levels: [], halls: []) unless base[:configured]

      entries = @event.event_halls.ordered.map { |hall| entry(hall) }
      timeline = entries.flat_map { |e| e[:series]&.keys || [] }.uniq.sort
      entries.each { |e| e[:fine] = e[:series] ? fine_points(e[:series], timeline) : nil }

      base.merge(
        event: scope(entries.filter_map { |e| e[:fine] }),
        levels: entries.group_by { |e| e[:hall].floor }.map do |floor, group|
          { floor: floor }.merge(scope(group.filter_map { |e| e[:fine] }))
        end,
        halls: entries.map do |e|
          { id: e[:hall].id, name: e[:hall].name, floor: e[:hall].floor, status: e[:status] }
            .merge(scope([e[:fine]].compact))
        end
      )
    end

    # { hall:, status:, series: { bucket => { in:, out: } } | nil }
    def entry(hall)
      return { hall: hall, status: "unlinked", series: nil } if hall.counter_venue_id.nil?

      day = Date.iso8601(@date)
      rows = client.venue_series(hall.counter_venue_id, from: day, to: day, bucket: 15)
      series = rows.to_h { |r| [r["bucket"], { in: r["in"].to_i, out: r["out"].to_i }] }
      { hall: hall, status: "ok", series: series }
    rescue Client::Error
      { hall: hall, status: "unavailable", series: nil }
    end

    # Every hall is laid over the same timeline so level sums line up bucket for bucket.
    def fine_points(series, timeline)
      occupancy = 0
      timeline.map do |bucket|
        i = series.dig(bucket, :in) || 0
        o = series.dig(bucket, :out) || 0
        occupancy = [occupancy + i - o, 0].max
        { bucket: bucket, in: i, out: o, occupancy: occupancy }
      end
    end

    def scope(fines)
      fine = sum_points(fines)
      { points: downsample(fine), stats: stats(fine) }
    end

    def sum_points(fines)
      return [] if fines.empty?

      fines.transpose.map do |column|
        { bucket: column.first[:bucket], in: column.sum { |p| p[:in] }, out: column.sum { |p| p[:out] },
          occupancy: column.sum { |p| p[:occupancy] } }
      end
    end

    # Hourly view: In/Out added up, occupancy as it stood at the end of the hour.
    def downsample(fine)
      return fine if @bucket == 15

      fine.group_by { |p| hour_of(p[:bucket]) }.map do |hour, group|
        { bucket: hour, in: group.sum { |p| p[:in] }, out: group.sum { |p| p[:out] }, occupancy: group.last[:occupancy] }
      end
    end

    # Peak crowd, busiest hour for arrivals, and the most recent 15 minutes with any movement.
    def stats(fine)
      return nil if fine.empty?

      peak = fine.max_by { |p| p[:occupancy] }
      busiest = fine.group_by { |p| hour_of(p[:bucket]) }
                    .map { |hour, g| { at: hour, in: g.sum { |p| p[:in] } } }.max_by { |h| h[:in] }
      last = fine.reverse.find { |p| (p[:in] + p[:out]).positive? }

      {
        peak: { occupancy: peak[:occupancy], at: peak[:bucket] },
        busiest_entry_hour: busiest,
        recent_flow: last && { net: last[:in] - last[:out], in: last[:in], out: last[:out], at: last[:bucket] }
      }
    end

    def hour_of(bucket)
      "#{bucket[0, 13]}:00:00"
    end
  end
end
