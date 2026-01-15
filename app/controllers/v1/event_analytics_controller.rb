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
      amount_cents = scoped_active_tickets.total_revenue_cents
      render json: { totalAmountPrice: amount_cents.to_i }, status: :ok
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
    #   metric: tickets | scans | revenue | visitors | visitor_scans | stamps | redemptions | redemption_value (required)
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
      top_merchants_data = VisitorVendorStamp.joins(:event_vendor)
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
      location_traffic = VisitorVendorStamp.joins(:event_vendor)
                                           .joins("INNER JOIN event_location_members ON event_location_members.member_id = event_vendors.vendor_id")
                                           .joins("INNER JOIN event_locations ON event_locations.id = event_location_members.event_location_id")
                                           .where(event_vendors: { event_id: @event.id })
                                           .where(event_locations: { event_id: @event.id })
                                           .group('event_locations.name')
                                           .count

      total_stamps = location_traffic.values.sum

      location_traffic.map do |name, count|
        {
          name: name,
          percentage: total_stamps.zero? ? 0 : ((count.to_f / total_stamps) * 100).round(1)
        }
      end.sort_by { |h| -h[:percentage] }
    end

    def today_range
      Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    end

    # --- Time Series Helpers ---

    def auto_group_by
      duration_days = (@event.end_date.to_date - @event.start_date.to_date).to_i
      case duration_days
      when 0..1   then 'hour'
      when 2..14  then 'day'
      when 15..60 then 'week'
      else 'month'
      end
    end

    def build_date_range
      start_date = parse_date(params[:start_date]) || @event.start_date.to_date
      end_date = parse_date(params[:end_date]) || @event.end_date.to_date
      start_date.beginning_of_day..end_date.end_of_day
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
      when 'stamps'
        VisitorVendorStamp.joins(:visitor)
                          .where(visitors: { event_id: @event.id })
                          .time_series_count(:created_at, range: range, group_by: group_by)
      when 'redemptions'
        VoucherRedemptionLog.for_event(@event)
                            .time_series_count(:redemption_timestamp, range: range, group_by: group_by)
      when 'redemption_value'
        VoucherRedemptionLog.for_event(@event)
                            .time_series_sum(:redemption_timestamp, :discount_applied_value, range: range, group_by: group_by)
      end
    end
  end
end
