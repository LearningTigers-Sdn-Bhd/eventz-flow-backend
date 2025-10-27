module V1
  class EventAnalyticsController < ApplicationController
    before_action :authenticate_user!
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

    private

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
  end
end
