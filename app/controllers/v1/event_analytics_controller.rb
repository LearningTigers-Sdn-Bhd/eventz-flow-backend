module V1
  class EventAnalyticsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_and_authorize

    # GET /v1/events/:event_id/metrics/total_tickets
    def total_tickets
      render json: {
        totalTickets: eligible_tickets.count,
        paidTickets: paid_tickets.count,
        pendingTickets: pending_tickets.count
      }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_scanned_tickets
    def total_scanned_tickets
      count = paid_tickets.checked_in.count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/total_unscanned_tickets
    def total_unscanned_tickets
      count = paid_tickets.unscanned.count
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
      paid_ticket_cents = paid_tickets.total_revenue_cents.to_i
      pending_ticket_cents = pending_tickets.total_revenue_cents.to_i
      paid_exhibitor_cents = ExhibitorRegistrationPayment
        .paid
        .joins(exhibitor_kit: :event_vendor)
        .where(event_vendors: { event_id: @event.id })
        .sum(:amount)
      pending_exhibitor_cents = ExhibitorRegistrationPayment
        .where(status: %w[pending submitted])
        .joins(exhibitor_kit: :event_vendor)
        .where(event_vendors: { event_id: @event.id })
        .sum(:amount)

      render json: {
        totalAmountPrice: paid_ticket_cents + (paid_exhibitor_cents.to_d * 100).to_i,
        pendingAmountPrice: pending_ticket_cents + (pending_exhibitor_cents.to_d * 100).to_i
      }, status: :ok
    end

    # GET /v1/events/:event_id/metrics/exhibitor_analytics
    # Returns exhibitor kit sales when exhibitor kits are enabled, otherwise
    # returns the event's merchant/vendor overview.
    def exhibitor_analytics
      payload = @event.use_exhibitor_kit? ? exhibitor_analytics_payload : vendor_analytics_payload
      render json: payload, status: :ok
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
    #   metric: tickets | scans | revenue | visitors | visitor_scans | leads | redemptions | redemption_value |
    #           exhibitor_bookings | exhibitor_revenue (required)
    #   group_by: hour | day | week | month (optional, auto-detected from event duration)
    #   start_date: YYYY-MM-DD (optional, defaults to event.start_date)
    #   end_date: YYYY-MM-DD (optional, defaults to event.end_date)
    def time_series
      metric = params[:metric]
      return render json: { error: 'metric parameter is required' }, status: :bad_request if metric.blank?

      group_by = params[:group_by].presence || auto_group_by
      range = build_date_range_for_metric(metric)

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

    def eligible_tickets
      @event.tickets.where(
        status: Ticket.statuses.values_at(:purchased, :scanned, :pending_payment),
        payment_status: Ticket.payment_statuses.values_at(:paid, :pending)
      )
    end

    def paid_tickets
      eligible_tickets.where(payment_status: :paid)
    end

    def pending_tickets
      eligible_tickets.where(payment_status: :pending)
    end

    def exhibitor_kits_for_analytics
      ExhibitorKit
        .joins(:event_vendor)
        .where(event_vendors: { event_id: @event.id })
        .merge(ExhibitorKit.active_or_paid)
        .includes(:event_vendor, :exhibitor_booth_price, :exhibitor_package,
                  :exhibitor_registration_payment)
    end

    def exhibitor_analytics_payload
      kits = exhibitor_kits_for_analytics.to_a
      partner_ids = kits.map(&:event_vendor_id).uniq
      paid_partner_ids = kits.select { |kit| settled_exhibitor_kit?(kit) }
                            .map(&:event_vendor_id).uniq

      {
        mode: 'exhibitor',
        totalPartners: partner_ids.size,
        paidPartners: paid_partner_ids.size,
        unpaidPartners: partner_ids.size - paid_partner_ids.size,
        collectedRevenue: exhibitor_collected_revenue(kits),
        pendingRevenue: exhibitor_pending_revenue(kits),
        breakdown: exhibitor_breakdown(kits),
        filterOptions: exhibitor_filter_options,
        vendorMetrics: vendor_metrics
      }
    end

    def vendor_analytics_payload
      {
        mode: 'vendor',
        totalPartners: @event.event_vendors.count,
        paidPartners: 0,
        unpaidPartners: 0,
        collectedRevenue: 0.0,
        pendingRevenue: 0.0,
        breakdown: [],
        vendorMetrics: vendor_metrics
      }
    end

    def vendor_metrics
      event_leads = EventLead.joins(:event_vendor)
                            .where(event_vendors: { event_id: @event.id })

      voucher_redemptions = VoucherRedemptionLog.for_event(@event)

      {
        totalLeads: event_leads.count,
        voucherSales: voucher_redemptions.sum(:transaction_net_amount).to_d.round(2).to_f,
        voucherRedemptions: voucher_redemptions.count
      }
    end

    def exhibitor_filter_options
      {
        zones: @event.exhibitor_zones.order(:zone, :id).pluck(:zone),
        boothPricing: @event.exhibitor_booth_prices.order(:label, :id).pluck(:label).uniq
      }
    end

    def settled_exhibitor_kit?(kit)
      kit.settled?
    end

    def exhibitor_collected_revenue(kits)
      kits.select(&:paid?).sum do |kit|
        payment = kit.exhibitor_registration_payment
        next payment.amount.to_d if payment&.status == 'paid'
        next kit.amount_paid.to_d if payment.nil?

        0.to_d
      end.round(2).to_f
    end

    def exhibitor_pending_revenue(kits)
      kits.select(&:unpaid?).sum(&:booking_value).round(2).to_f
    end

    def exhibitor_breakdown(kits)
      kits_by_key = kits.group_by do |kit|
        [kit.exhibitor_booth_price_id, kit.exhibitor_package_id,
         kit.exhibitor_booth_price&.label || kit.booth_type]
      end

      rows = kits_by_key.map do |_key, grouped_kits|
        first_kit = grouped_kits.first
        booth_price = first_kit.exhibitor_booth_price
        package = first_kit.exhibitor_package
        paid_kits = grouped_kits.select { |kit| settled_exhibitor_kit?(kit) }
        unpaid_kits = grouped_kits.select(&:unpaid?)

        {
          breakdownKey: [
            first_kit.exhibitor_booth_price_id || 'booth-type',
            first_kit.exhibitor_package_id || 'base-package',
            first_kit.booth_type || 'unknown'
          ].join(':'),
          label: booth_price&.label || first_kit.booth_type.to_s.humanize,
          zone: booth_price&.zone,
          boothType: booth_price&.booth_type || first_kit.booth_type,
          packageLabel: package&.name,
          bookedQuantity: grouped_kits.sum { |kit| [kit.booth_quantity.to_i, 1].max },
          paidQuantity: paid_kits.sum { |kit| [kit.booth_quantity.to_i, 1].max },
          unpaidQuantity: unpaid_kits.sum { |kit| [kit.booth_quantity.to_i, 1].max },
          collectedRevenue: exhibitor_collected_revenue(grouped_kits),
          pendingRevenue: exhibitor_pending_revenue(grouped_kits)
        }
      end

      booked_price_ids = kits_by_key.keys.map(&:first).compact.uniq
      unbooked_price_rows = @event.exhibitor_booth_prices.includes(:exhibitor_zone)
        .to_a
        .reject { |booth_price| booked_price_ids.include?(booth_price.id) }
        .map do |booth_price|
          {
            breakdownKey: [booth_price.id, 'base-package', booth_price.booth_type || 'unknown'].join(':'),
            label: booth_price.label,
            zone: booth_price.zone,
            boothType: booth_price.booth_type,
            packageLabel: nil,
            bookedQuantity: 0,
            paidQuantity: 0,
            unpaidQuantity: 0,
            collectedRevenue: 0.0,
            pendingRevenue: 0.0
          }
        end

      (rows + unbooked_price_rows).sort_by { |entry| [entry[:label], entry[:zone].to_s, entry[:packageLabel].to_s] }
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
      when 'exhibitor_bookings'
        earliest = exhibitor_kits_for_analytics.minimum(:created_at)
        earliest&.to_date || @event.start_date.to_date
      when 'exhibitor_revenue'
        earliest = exhibitor_registration_payments_for_analytics.minimum(:paid_at)
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
      when 'exhibitor_bookings'
        latest = exhibitor_kits_for_analytics.maximum(:created_at)
        latest&.to_date || @event.end_date.to_date
      when 'exhibitor_revenue'
        latest = exhibitor_registration_payments_for_analytics.maximum(:paid_at)
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
        eligible_tickets.time_series_count(:created_at, range: range, group_by: group_by)
      when 'scans'
        paid_tickets.checked_in.time_series_count(:check_in_at, range: range, group_by: group_by)
      when 'revenue'
        paid_tickets
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
      when 'exhibitor_bookings'
        exhibitor_kits_for_analytics
          .where(created_at: range)
          .send(groupdate_method(group_by), :created_at)
          .count
          .map { |period, value| { period: format_time_series_period(period, group_by), value: value } }
      when 'exhibitor_revenue'
        exhibitor_registration_payments_for_analytics
          .where(paid_at: range)
          .send(groupdate_method(group_by), :paid_at)
          .sum(:amount)
          .map { |period, value| { period: format_time_series_period(period, group_by), value: value.to_f } }
      end
    end

    def exhibitor_registration_payments_for_analytics
      ExhibitorRegistrationPayment
        .paid
        .joins(exhibitor_kit: :event_vendor)
        .where(event_vendors: { event_id: @event.id })
    end

    def groupdate_method(group_by)
      { 'hour' => :group_by_hour, 'day' => :group_by_day, 'week' => :group_by_week, 'month' => :group_by_month }.fetch(group_by)
    end

    def format_time_series_period(period, group_by)
      case group_by
      when 'hour'  then period.strftime('%Y-%m-%d %H:00')
      when 'week', 'day' then period.strftime('%Y-%m-%d')
      when 'month' then period.strftime('%Y-%m')
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
        eligible_tickets
      when 'scans'
        paid_tickets.checked_in
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
