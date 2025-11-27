module V1
  class AnalyticsController < ApplicationController
    before_action :set_deprecation_headers_for_legacy_paths
    before_action :authorize_global_analytics, only: [
      :total_tickets,
      :total_scanned_tickets,
      :total_unscanned_tickets,
      :total_amount_price,
      :weekly_registered_tickets,
      :weekly_scanned_tickets,
      :weekly_sales_amount
    ]

    # === OPTIMIZED BULK ENDPOINTS (Works for all roles) ===

    # GET /v1/analytics/events_overview
    def events_overview
      @events = policy_scope(Event)

      events_data = @events.map do |event|
        if event.use_ticket
          # Ticket-based event analytics
          tickets = event.tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
          {
            id: event.id,
            title: event.title,
            status: event.status,
            use_ticket: event.use_ticket,
            total_tickets: tickets.count,
            scanned_tickets: event.tickets.checked_in.count,
            unscanned_tickets: event.tickets.unscanned.count,
            total_revenue: tickets.joins(:ticket_type).sum("ticket_types.price * 100.0").to_i,
            total_visitors: 0,
            total_stamps: 0,
            last_activity: event.updated_at
          }
        else
          # Non-ticket (visitor) event analytics
          {
            id: event.id,
            title: event.title,
            status: event.status,
            use_ticket: event.use_ticket,
            total_tickets: 0,
            scanned_tickets: 0,
            unscanned_tickets: 0,
            total_revenue: 0,
            total_visitors: event.visitors.count,
            total_stamps: VisitorVendorStamp.joins(:visitor).where(visitors: { event_id: event.id }).count,
            last_activity: event.updated_at
          }
        end
      end

      render json: { events: events_data }, status: :ok
    end

    # GET /v1/analytics/summary
    def summary
      @events = policy_scope(Event)
      event_ids = @events.pluck(:id)

      ticket_events = @events.where(use_ticket: true)
      non_ticket_events = @events.where(use_ticket: false)
      
      ticket_event_ids = ticket_events.pluck(:id)
      non_ticket_event_ids = non_ticket_events.pluck(:id)

      # Ticket event stats
      all_tickets = Ticket.where(event_id: ticket_event_ids)
      active_tickets = all_tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
      
      # Non-ticket event stats
      total_visitors = Visitor.where(event_id: non_ticket_event_ids).count

      # Both event type stats
      total_vendors = EventVendor.where(event_id: event_ids).count
      # Exclude unlimited vouchers from total count as they don't have a fixed quota
      total_vouchers = Voucher.where(event_id: event_ids, is_unlimited: false).sum(:total_redemption_available)
      total_vouchers_redeemed = VoucherRedemptionLog.joins(:voucher).where(vouchers: { event_id: event_ids }).count

      render json: {
        total_events: @events.count,
        active_events: @events.where(status: 'published').count,
        total_tickets: active_tickets.count,
        total_scanned: all_tickets.checked_in.count,
        total_revenue: active_tickets.joins(:ticket_type).sum("ticket_types.price * 100.0").to_i,
        total_locations: EventLocation.where(event_id: event_ids).count,
        total_visitors: total_visitors,
        total_vendors: total_vendors,
        total_vouchers: total_vouchers,
        total_vouchers_redeemed: total_vouchers_redeemed,
        ticket_events: ticket_events.count,
        non_ticket_events: non_ticket_events.count
      }, status: :ok
    end

    # === EXISTING GLOBAL ENDPOINTS (Requires org_owner/organizer) ===

    # GET /v1/analytics/total_tickets
    def total_tickets
      count = scoped_active_tickets.count
      render json: { totalTickets: count }, status: :ok
    end

    # GET /v1/analytics/total_scanned_tickets
    def total_scanned_tickets
      count = scoped_tickets.checked_in.count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/analytics/total_unscanned_tickets
    def total_unscanned_tickets
      count = scoped_tickets.unscanned.count
      render json: { totalUnscannedTickets: count }, status: :ok
    end

    # GET /v1/analytics/total_amount_price
    def total_amount_price
      amount_cents = scoped_active_tickets.total_revenue_cents
      render json: { totalAmountPrice: amount_cents.to_i }, status: :ok
    end

    # GET /v1/analytics/weekly_registered_tickets
    def weekly_registered_tickets
      range = seven_day_range
      data = scoped_active_tickets.weekly_series(:created_at, range)
      render json: { weeklyRegisteredTickets: data }, status: :ok
    end

    # GET /v1/analytics/weekly_scanned_tickets
    def weekly_scanned_tickets
      range = seven_day_range
      data = scoped_tickets.checked_in.weekly_series(:check_in_at, range)
      render json: { weeklyScannedTickets: data }, status: :ok
    end

    # GET /v1/analytics/weekly_sales_amount
    def weekly_sales_amount
      range = seven_day_range
      data = scoped_active_tickets.weekly_revenue_series(range)
      render json: { weeklySalesAmount: data }, status: :ok
    end

    private

    def set_deprecation_headers_for_legacy_paths
      # Add Deprecation/Sunset headers for legacy /analytics paths
      if request.path.include?("/v1/analytics/")
        response.set_header('Deprecation', 'true')
        # Sunset in 90 days
        response.set_header('Sunset', (Time.now.utc + 90.days).httpdate)
        response.set_header('Link', '<https://api-docs>; rel="deprecation"')
      end
    end

    def authorize_global_analytics
      authorize :analytics, :index?
    end

    def scoped_tickets
      # Use policy_scope to get tickets user has access to across all events
      # Explicitly use AnalyticsPolicy::Scope
      AnalyticsPolicy::Scope.new(current_user, Ticket).resolve
    end

    def scoped_active_tickets
      # Active = purchased or scanned
      scoped_tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
    end

    def seven_day_range
      today = Time.zone ? Time.zone.today : Date.today
      (today - 6)..today
    end
  end
end
