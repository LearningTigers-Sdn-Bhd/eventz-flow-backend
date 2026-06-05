module V1
  class EventAnalyticsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_and_authorize

    # GET /v1/events/:event_id/metrics/total_tickets
    def total_tickets
      count = scoped_active_tickets.count
      render json: { totalTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_scanned_tickets
    def total_scanned_tickets
      count = @event.tickets.checked_in.count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_unscanned_tickets
    def total_unscanned_tickets
      count = @event.tickets.unscanned.count
      render json: { totalUnscannedTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_visitors
    def total_visitors
      count = @event.visitors.count
      render json: { totalVisitors: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_scanned_visitors
    def total_scanned_visitors
      count = @event.visitors.checked_in.count
      render json: { totalScannedVisitors: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_unscanned_visitors
    def total_unscanned_visitors
      count = @event.visitors.unscanned.count
      render json: { totalUnscannedVisitors: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_amount_price
    def total_amount_price
      ticket_revenue_cents = scoped_active_tickets.total_revenue_cents.to_i
      exhibitor_revenue_cents = ExhibitorRegistrationPayment
        .paid
        .joins(exhibitor_kit: :event_vendor)
        .where(event_vendors: { event_id: @event.id })
        .sum(:amount)
      exhibitor_revenue_cents = (exhibitor_revenue_cents.to_d * 100).to_i
      total = ticket_revenue_cents + exhibitor_revenue_cents
      render json: { totalAmountPrice: total }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/mall_live_feed
    def mall_live_feed
      render json: {
        shoppers_registered_today: count_shoppers_today,
        estimated_sales_today: calculate_sales_today,
        voucher_issuances: total_vouchers_issued,
        voucher_redemptions: total_voucher_redemptions,
        redemption_rate: calculate_redemption_rate,
        top_merchants: fetch_top_merchants,
        popular_halls: fetch_popular_halls
      }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/time_series
    # Flexible time-series analytics with hourly, daily, weekly, monthly grouping.
    #
    # Query params:
    #   metric: tickets | scans | revenue | visitors | visitor_scans | leads | redemptions | redemption_value (required)
    #   group_by: hour | day | week | month (optional, auto-detected from event duration)
    #   start_date: YYYY-MM-DD (optional, defaults to event.start_date)
    #   end_date: YYYY-MM-DD (optional, defaults to event.end_date)
    def time_series
      metric = params[:metric]
      return render json: { error: 'metric parameter is required' }, status: :bad_request if metric.blank?

      group_by = params[:group_by].presence || auto_group_by
      range = build_date_range

      data = fetch_time_series_data(metric, range, group_by)
      return render json: { error: "Invalid metric: #{metric}" }, status: :bad_request if data.nil?

      render json: {
        metric: metric,
        group_by: group_by,
        start_date: range.begin.to_date.to_s,
        end_date: range.end.to_date.to_s,
        data: data
      }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/hourly_breakdown_by_day
    # Returns hourly data grouped by day - useful for multi-day event reports.
    #
    # Query params:
    #   metric: scans | visitors | visitor_scans | tickets | leads | redemptions (required)
    #   start_date: YYYY-MM-DD (optional, defaults to event.start_date)
    #   end_date: YYYY-MM-DD (optional, defaults to event.end_date)
    def hourly_breakdown_by_day
      metric = params[:metric]
      return render json: { error: 'metric parameter is required' }, status: :bad_request if metric.blank?

      range = build_date_range_for_metric(metric)
      data = fetch_hourly_breakdown_by_day(metric, range)
      return render json: { error: "Invalid metric: #{metric}" }, status: :bad_request if data.nil?

      render json: {
        metric: metric,
        start_date: range.begin.to_date.to_s,
        end_date: range.end.to_date.to_s,
        data: data
      }, status: :ok
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :analytics?
    end

    def scoped_active_tickets
      @event.tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
    end

    def count_shoppers_today
      @event.visitors.where(created_at: today_range).count
    end

    def calculate_sales_today
      VoucherRedemptionLog.for_event(@event)
                          .where(redemption_timestamp: today_range)
                          .sum(:transaction_net_amount)
    end

    def total_vouchers_issued
      @total_vouchers_issued ||= Voucher.for_event(@event).where(is_unlimited: false).sum(:total_redemption_available)
    end

    def total_voucher_redemptions
      @total_voucher_redemptions ||= VoucherRedemptionLog.for_event(@event).count
    end

    def calculate_redemption_rate
      return 0.0 if total_vouchers_issued.zero?
      (total_voucher_redemptions.to_f / total_vouchers_issued * 100).round(1)
    end

    def fetch_top_merchants
      top_merchants_data = EventLead.joins(:event_vendor)
                                     .where(event_vendors: { event_id: @event.id })
                                     .group(:event_vendor_id)
                                     .order('count_all DESC')
                                     .limit(5)
                                     .count

      vendors = EventVendor.includes(:vendor).find(top_merchants_data.keys).index_by(&:id)

      top_merchants_data.map do |ev_id, count|
        ev = vendors[ev_id]
        next unless ev

        {
          name: ev.vendor&.full_name || ev.vendor&.email || "Unknown Vendor",
          count: count
        }
      end.compact
    end

    def fetch_popular_halls
      location_traffic = EventLead.joins(:event_vendor)
                                   .joins("INNER JOIN event_location_members ON event_location_members.member_id = event_vendors.vendor_id")
                                   .joins("INNER JOIN event_locations ON event_locations.id = event_location_members.event_location_id")
                                   .where(event_vendors: { event_id: @event.id })
                                   .where(event_locations: { event_id: @event.id })
                                   .group('event_locations.name')
                                   .count

      total_leads = location_traffic.values.sum

      location_traffic.map do |name, count|
        {
          name: name,
          percentage: total_leads.zero? ? 0 : ((count.to_f / total_leads) * 100).round(1)
        }
      end.sort_by { |h| -h[:percentage] }
    end

    def today_range
      Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    end

    # --- Time Series Helpers ---

    def auto_group_by
      range = build_date_range
      duration_days = (range.end.to_date - range.begin.to_date).to_i
      case duration_days
      when 0..1   then 'hour'
      when 2..14  then 'day'
      when 15..60 then 'week'
      else 'month'
      end
    end

    def build_date_range
      date_mode = params[:date_mode]

      case date_mode
      when 'all_time'
        # From the earliest registration to now (or event end, whichever is later)
        earliest_date = find_earliest_registration_date
        latest_date = [Time.current, @event.end_date].max
        earliest_date.beginning_of_day..latest_date.end_of_day
      when 'pre_event'
        # From the earliest registration to event start
        earliest_date = find_earliest_registration_date
        earliest_date.beginning_of_day..@event.start_date.beginning_of_day
      else
        # Default: use provided dates or event duration
        start_date = parse_date(params[:start_date]) || @event.start_date.to_date
        end_date = parse_date(params[:end_date]) || @event.end_date.to_date
        start_date.beginning_of_day..end_date.end_of_day
      end
    end

    def find_earliest_registration_date
      # Find the earliest registration across tickets and visitors
      earliest_ticket = @event.tickets.minimum(:created_at)
      earliest_visitor = @event.visitors.minimum(:created_at)

      candidates = [earliest_ticket, earliest_visitor, @event.start_date].compact
      candidates.min.to_date
    end

    def find_earliest_date_for_metric(metric)
      case metric
      when 'scans'
        # For ticket scans, use earliest check_in_at
        earliest = @event.tickets.checked_in.minimum(:check_in_at)
        earliest&.to_date || @event.start_date.to_date
      when 'visitor_scans'
        # For visitor scans, use earliest check_in_at
        earliest = @event.visitors.checked_in.minimum(:check_in_at)
        earliest&.to_date || @event.start_date.to_date
      when 'leads'
        # For leads, use earliest lead created_at
        earliest = EventLead.joins(:event_vendor)
                            .where(event_vendors: { event_id: @event.id })
                            .minimum(:created_at)
        earliest&.to_date || @event.start_date.to_date
      when 'redemptions', 'redemption_value'
        # For redemptions, use earliest redemption_timestamp
        earliest = VoucherRedemptionLog.for_event(@event).minimum(:redemption_timestamp)
        earliest&.to_date || @event.start_date.to_date
      else
        # For tickets, visitors, revenue - use earliest registration
        find_earliest_registration_date
      end
    end

    def find_latest_date_for_metric(metric)
      case metric
      when 'scans'
        latest = @event.tickets.checked_in.maximum(:check_in_at)
        latest&.to_date || @event.end_date.to_date
      when 'visitor_scans'
        latest = @event.visitors.checked_in.maximum(:check_in_at)
        latest&.to_date || @event.end_date.to_date
      when 'leads'
        latest = EventLead.joins(:event_vendor)
                          .where(event_vendors: { event_id: @event.id })
                          .maximum(:created_at)
        latest&.to_date || @event.end_date.to_date
      when 'redemptions', 'redemption_value'
        latest = VoucherRedemptionLog.for_event(@event).maximum(:redemption_timestamp)
        latest&.to_date || @event.end_date.to_date
      when 'tickets', 'revenue'
        latest = @event.tickets.maximum(:created_at)
        latest&.to_date || @event.end_date.to_date
      when 'visitors'
        latest = @event.visitors.maximum(:created_at)
        latest&.to_date || @event.end_date.to_date
      else
        @event.end_date.to_date
      end
    end

    def build_date_range_for_metric(metric)
      date_mode = params[:date_mode]

      case date_mode
      when 'all_time'
        # From the earliest data for this metric to now (or event end, whichever is later)
        earliest_date = find_earliest_date_for_metric(metric)
        latest_date = find_latest_date_for_metric(metric)
        earliest_date.beginning_of_day..latest_date.end_of_day
      when 'pre_event'
        # From the earliest data to event start (only makes sense for registration metrics)
        earliest_date = find_earliest_date_for_metric(metric)
        earliest_date.beginning_of_day..@event.start_date.beginning_of_day
      else
        # Default: use provided dates or event duration
        start_date = parse_date(params[:start_date]) || @event.start_date.to_date
        end_date = parse_date(params[:end_date]) || @event.end_date.to_date
        start_date.beginning_of_day..end_date.end_of_day
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    def fetch_time_series_data(metric, range, group_by)
      case metric
      when 'tickets'
        scoped_active_tickets.time_series_count(:created_at, range: range, group_by: group_by)
      when 'scans'
        @event.tickets.checked_in.time_series_count(:check_in_at, range: range, group_by: group_by)
      when 'revenue'
        scoped_active_tickets
          .joins(:ticket_type)
          .time_series_sum(:created_at, '(ticket_types.price * 100.0)', range: range, group_by: group_by)
      when 'visitors'
        @event.visitors.time_series_count(:created_at, range: range, group_by: group_by)
      when 'visitor_scans'
        @event.visitors.checked_in.time_series_count(:check_in_at, range: range, group_by: group_by)
      when 'leads'
        EventLead.joins(:event_vendor)
                 .where(event_vendors: { event_id: @event.id })
                 .time_series_count(:created_at, range: range, group_by: group_by)
      when 'redemptions'
        VoucherRedemptionLog.for_event(@event)
                            .time_series_count(:redemption_timestamp, range: range, group_by: group_by)
      when 'redemption_value'
        VoucherRedemptionLog.for_event(@event)
                            .time_series_sum(:redemption_timestamp, :discount_applied_value, range: range, group_by: group_by)
      end
    end

    # Fetches hourly data for each day in the range, grouped by day.
    # Returns array of { date: "YYYY-MM-DD", hourlyData: [{ hour: "HH:00", value: N }, ...] }
    def fetch_hourly_breakdown_by_day(metric, range)
      scope = build_scope_for_metric(metric)
      return nil if scope.nil?

      timestamp_column = timestamp_column_for_metric(metric)

      # Get all days in the range
      start_date = range.begin.to_date
      end_date = range.end.to_date
      days = (start_date..end_date).to_a

      days.map do |day|
        day_range = day.beginning_of_day..day.end_of_day
        hourly_data = scope.where(timestamp_column => day_range)
                           .group_by_hour(timestamp_column)
                           .count

        {
          date: day.strftime('%Y-%m-%d'),
          hourlyData: format_hourly_data(hourly_data, day)
        }
      end
    end

    def build_scope_for_metric(metric)
      case metric
      when 'tickets'
        scoped_active_tickets
      when 'scans'
        @event.tickets.checked_in
      when 'visitors'
        @event.visitors
      when 'visitor_scans'
        @event.visitors.checked_in
      when 'leads'
        EventLead.joins(:event_vendor).where(event_vendors: { event_id: @event.id })
      when 'redemptions'
        VoucherRedemptionLog.for_event(@event)
      end
    end

    def timestamp_column_for_metric(metric)
      case metric
      when 'scans', 'visitor_scans'
        :check_in_at
      when 'redemptions'
        :redemption_timestamp
      else
        :created_at
      end
    end

    def format_hourly_data(hourly_data, day)
      # Generate all 24 hours for the day, filling in zeros where no data
      (0..23).map do |hour|
        hour_time = day.beginning_of_day + hour.hours
        value = hourly_data[hour_time] || 0
        {
          hour: format('%02d:00', hour),
          value: value
        }
      end
    end
  end
end
