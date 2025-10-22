module V1
  class EventAnalyticsController < ApplicationController
    before_action :authenticate_request!
    before_action :set_event_and_authorize

    # GET /v1/events/:event_id/analytics/total_tickets
    def total_tickets
      count = scoped_active_tickets.count
      render json: { totalTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/total_scanned_tickets
    def total_scanned_tickets
      count = @event.tickets.where(checked_in: true).count
      render json: { totalScannedTickets: count }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/total_unscanned_tickets
    def total_unscanned_tickets
      total = scoped_active_tickets.count
      scanned = @event.tickets.where(checked_in: true).count
      render json: { totalUnscannedTickets: (total - scanned) }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/total_amount_price
    def total_amount_price
      amount_cents = scoped_active_tickets
        .joins(:ticket_type)
        .sum("(ticket_types.price * 100.0)")

      # Return integer cents to avoid float rounding issues in clients
      render json: { totalAmountPrice: amount_cents.to_i }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/weekly_registered_tickets
    def weekly_registered_tickets
      render json: { weeklyRegisteredTickets: series_for(@event.tickets.merge(scoped_active_tickets), :created_at) }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/weekly_scanned_tickets
    def weekly_scanned_tickets
      scanned_scope = @event.tickets.where(checked_in: true)
      render json: { weeklyScannedTickets: series_for(scanned_scope, :check_in_at) }, status: :ok
    end

    # GET /v1/events/:event_id/analytics/weekly_sales_amount
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
