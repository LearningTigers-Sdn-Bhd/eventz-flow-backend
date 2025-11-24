module V1
  class EventAnalyticsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_deprecation_headers_for_legacy_paths
    before_action :set_event_and_authorize

    # GET /v1/events/:event_id/analytics/total_tickets
    def total_tickets
      count = scoped_active_tickets.count
      render json: { totalTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/total_scanned_tickets
    def total_scanned_tickets
      count = @event.tickets.checked_in.count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/total_unscanned_tickets
    def total_unscanned_tickets
      count = @event.tickets.unscanned.count
      render json: { totalUnscannedTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/total_amount_price
    def total_amount_price
      amount_cents = scoped_active_tickets.total_revenue_cents
      render json: { totalAmountPrice: amount_cents.to_i }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/weekly_registered_tickets
    def weekly_registered_tickets
      range = seven_day_range
      data = scoped_active_tickets.weekly_series(:created_at, range)
      render json: { weeklyRegisteredTickets: data }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/weekly_scanned_tickets
    def weekly_scanned_tickets
      range = seven_day_range
      data = @event.tickets.checked_in.weekly_series(:check_in_at, range)
      render json: { weeklyScannedTickets: data }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/weekly_sales_amount
    def weekly_sales_amount
      range = seven_day_range
      data = scoped_active_tickets.weekly_revenue_series(range)
      render json: { weeklySalesAmount: data }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/mall_live_feed
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

    private

    def set_deprecation_headers_for_legacy_paths
      if request.path.include?("/v1/events/") && request.path.include?("/analytics/")
        response.set_header('Deprecation', 'true')
        response.set_header('Sunset', (Time.now.utc + 90.days).httpdate)
        response.set_header('Link', '<https://api-docs>; rel="deprecation"')
      end
    end

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      # For analytics, only allow event staff/managers, not just anyone who can view the event
      authorize @event, :analytics?
    end

    def scoped_active_tickets
      # Active = purchased or scanned
      @event.tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
    end

    def seven_day_range
      today = Time.zone ? Time.zone.today : Date.today
      (today - 6)..today
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
      @total_vouchers_issued ||= Voucher.for_event(@event).sum(:total_redemption_available)
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
      # Join visitor stamps -> event vendors -> location members -> locations
      # This tracks which locations (halls) get the most visitor traffic based on vendor stamps
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
  end
end
