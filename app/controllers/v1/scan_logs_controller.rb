module V1
  class ScanLogsController < ApplicationController
    before_action :set_event_and_authorize

    def index
      scope = filtered_scope

      @pagy, logs = pagy(scope, limit: pagination_params[:per_page])

      success_response(
        data: logs.map { |log| format_scan_log(log) },
        pagination: pagy_metadata(@pagy)
      )
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :show?
    end

    def filtered_scope
      apply_filters(
        policy_scope(ScanLog).where(event_id: @event.id)
      ).includes(:event_location, :scanned_by, scannable: :ticket_type)
       .order(scanned_at: :desc)
    end

    def apply_filters(scope)
      scope = scope.where(scannable_type: params[:scannable_type]) if params[:scannable_type].present?
      scope = scope.where(scannable_id: params[:scannable_id]) if params[:scannable_id].present?
      scope = scope.where(event_location_id: params[:event_location_id]) if params[:event_location_id].present?
      scope = scope.where(source: params[:source]) if params[:source].present?
      scope = scope.on_date(Date.parse(params[:date])) if params[:date].present?
      scope = filter_by_name(scope, params[:q]) if params[:q].present?
      scope = filter_by_ticket_type(scope, params[:ticket_type_id]) if params[:ticket_type_id].present?
      scope
    end

    # Ticket type only exists on Ticket scans - Visitor walk-ins have none, so
    # filtering by it implicitly excludes Visitor rows.
    def filter_by_ticket_type(scope, ticket_type_id)
      ticket_ids = Ticket.where(event_id: @event.id, ticket_type_id: ticket_type_id).select(:id)
      scope.where(scannable_type: 'Ticket', scannable_id: ticket_ids)
    end

    def filter_by_name(scope, query)
      pattern = "%#{query.downcase}%"

      ticket_ids = Ticket.where(event_id: @event.id)
                         .where('LOWER(attendee_name) LIKE ?', pattern).select(:id)
      visitor_ids = Visitor.where(event_id: @event.id)
                           .where('LOWER(full_name) LIKE ?', pattern).select(:id)

      scope.where(scannable_type: 'Ticket', scannable_id: ticket_ids)
           .or(scope.where(scannable_type: 'Visitor', scannable_id: visitor_ids))
    end

    def format_scan_log(log)
      scannable = log.scannable

      {
        id: log.id,
        scanned_at: log.scanned_at&.iso8601,
        source: log.source,
        scannable_type: log.scannable_type,
        scannable_id: log.scannable_id,
        public_id: scannable&.public_id,
        name: scannable.is_a?(Ticket) ? scannable.attendee_name : scannable&.full_name,
        email: scannable.is_a?(Ticket) ? scannable.attendee_email : scannable&.email,
        phone: scannable.is_a?(Ticket) ? scannable.attendee_phone : scannable&.phone,
        ticket_type_name: scannable.is_a?(Ticket) ? scannable.ticket_type&.name : nil,
        location_name: log.event_location&.name,
        scanned_by_name: log.scanned_by&.full_name
      }
    end
  end
end
