module V1
  class AnalyticsController < ApplicationController
    before_action :authenticate_request!
    before_action :authorize_global_analytics

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
