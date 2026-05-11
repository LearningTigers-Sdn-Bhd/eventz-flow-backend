module V1
  class AnalyticsController < ApplicationController
    before_action :authorize_global_analytics, only: [
      :total_tickets,
      :total_scanned_tickets,
      :total_unscanned_tickets,
      :total_amount_price
    ]

    # === OPTIMIZED BULK ENDPOINTS (Works for all roles) ===

    # GET /v1/metrics/events_overview
    def events_overview
      @events = policy_scope(Event)
      exhibitor_revenue_by_event = exhibitor_revenue_cents_by_event(@events.pluck(:id))

      events_data = @events.map do |event|
        exhibitor_revenue_cents = exhibitor_revenue_by_event[event.id] || 0

        if event.use_ticket
          tickets = event.tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
          {
            id: event.id,
            title: event.title,
            status: event.status,
            use_ticket: event.use_ticket,
            total_tickets: tickets.count,
            scanned_tickets: event.tickets.checked_in.count,
            unscanned_tickets: event.tickets.unscanned.count,
            total_revenue: tickets.joins(:ticket_type).sum("ticket_types.price * 100.0").to_i + exhibitor_revenue_cents,
            total_visitors: 0,
            total_leads: 0,
            last_activity: event.updated_at
          }
        else
          {
            id: event.id,
            title: event.title,
            status: event.status,
            use_ticket: event.use_ticket,
            total_tickets: 0,
            scanned_tickets: 0,
            unscanned_tickets: 0,
            total_revenue: exhibitor_revenue_cents,
            total_visitors: event.visitors.count,
            scanned_visitors: event.visitors.checked_in.count,
            unscanned_visitors: event.visitors.unscanned.count,
            total_leads: EventLead.joins(:event_vendor).where(event_vendors: { event_id: event.id }).count,
            last_activity: event.updated_at
          }
        end
      end

      render json: { events: events_data }, status: :ok
    end

    # GET /v1/metrics/summary
    def summary
      @events = policy_scope(Event)
      event_ids = @events.pluck(:id)

      ticket_events = @events.where(use_ticket: true)
      non_ticket_events = @events.where(use_ticket: false)

      ticket_event_ids = ticket_events.pluck(:id)
      non_ticket_event_ids = non_ticket_events.pluck(:id)

      all_tickets = Ticket.where(event_id: ticket_event_ids)
      active_tickets = all_tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
      exhibitor_revenue_cents = exhibitor_revenue_cents_by_event(event_ids).values.sum

      total_visitors = Visitor.where(event_id: non_ticket_event_ids).count
      total_vendors = EventVendor.where(event_id: event_ids).count
      total_vouchers = Voucher.where(event_id: event_ids, is_unlimited: false).sum(:total_redemption_available)
      total_vouchers_redeemed = VoucherRedemptionLog.joins(:voucher).where(vouchers: { event_id: event_ids }).count

      render json: {
        total_events: @events.count,
        active_events: @events.where(status: 'published').count,
        total_tickets: active_tickets.count,
        total_scanned: all_tickets.checked_in.count,
        total_revenue: active_tickets.joins(:ticket_type).sum("ticket_types.price * 100.0").to_i + exhibitor_revenue_cents,
        total_locations: EventLocation.where(event_id: event_ids).count,
        total_visitors: total_visitors,
        total_vendors: total_vendors,
        total_vouchers: total_vouchers,
        total_vouchers_redeemed: total_vouchers_redeemed,
        ticket_events: ticket_events.count,
        non_ticket_events: non_ticket_events.count
      }, status: :ok
    end

    # === GLOBAL TOTALS (Requires org_owner/organizer) ===

    # GET /v1/metrics/total_tickets
    def total_tickets
      count = scoped_active_tickets.count
      render json: { totalTickets: count }, status: :ok
    end

    # GET /v1/metrics/total_scanned_tickets
    def total_scanned_tickets
      count = scoped_tickets.checked_in.count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/metrics/total_unscanned_tickets
    def total_unscanned_tickets
      count = scoped_tickets.unscanned.count
      render json: { totalUnscannedTickets: count }, status: :ok
    end

    # GET /v1/metrics/total_amount_price
    def total_amount_price
      amount_cents = scoped_active_tickets.total_revenue_cents
      render json: { totalAmountPrice: amount_cents.to_i }, status: :ok
    end

    private

    def authorize_global_analytics
      authorize :analytics, :index?
    end

    def exhibitor_revenue_cents_by_event(event_ids)
      return {} if event_ids.empty?

      ExhibitorRegistrationPayment
        .paid
        .joins(exhibitor_kit: :event_vendor)
        .where(event_vendors: { event_id: event_ids })
        .group("event_vendors.event_id")
        .sum(:amount)
        .transform_values { |amount| (amount.to_d * 100).to_i }
    end

    def scoped_tickets
      AnalyticsPolicy::Scope.new(current_user, Ticket).resolve
    end

    def scoped_active_tickets
      scoped_tickets.where(status: [Ticket.statuses[:purchased], Ticket.statuses[:scanned]])
    end
  end
end
