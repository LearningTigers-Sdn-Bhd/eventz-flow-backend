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
      count = scoped_tickets.where(checked_in: true).count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/analytics/total_unscanned_tickets
    def total_unscanned_tickets
      total = scoped_active_tickets.count
      scanned = scoped_tickets.where(checked_in: true).count
      render json: { totalUnscannedTickets: (total - scanned) }, status: :ok
    end

    # GET /v1/analytics/total_amount_price
    def total_amount_price
      amount_cents = scoped_active_tickets
        .joins(:ticket_type)
        .sum("(ticket_types.price * 100.0)")

      # Return integer cents to avoid float rounding issues in clients
      render json: { totalAmountPrice: amount_cents.to_i }, status: :ok
    end

    # GET /v1/analytics/weekly_registered_tickets
    def weekly_registered_tickets
      render json: { weeklyRegisteredTickets: series_for(scoped_active_tickets, :created_at) }, status: :ok
    end

    # GET /v1/analytics/weekly_scanned_tickets
    def weekly_scanned_tickets
      scanned_scope = scoped_tickets.where(checked_in: true)
      render json: { weeklyScannedTickets: series_for(scanned_scope, :check_in_at) }, status: :ok
    end

    # GET /v1/analytics/weekly_sales_amount
    def weekly_sales_amount
      scope = scoped_active_tickets.joins(:ticket_type)
      range = seven_day_range

      grouped = scope
        .where(created_at: range)
        .group(Arel.sql("DATE(tickets.created_at)"))
        .sum("(ticket_types.price * 100.0)")

      data = dates_for(range).map do |date|
        { date: date.to_s, count: grouped.fetch(date, 0).to_i }
      end

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

    def dates_for(range)
      range.to_a
    end

    def series_for(scope, timestamp_column)
      range = seven_day_range

      grouped = scope
        .where(timestamp_column => range)
        .group(Arel.sql("DATE(#{ActiveRecord::Base.connection.quote_column_name(timestamp_column.to_s)})"))
        .count

      dates_for(range).map do |date|
        { date: date.to_s, count: grouped.fetch(date, 0) }
      end
    end
  end
end
