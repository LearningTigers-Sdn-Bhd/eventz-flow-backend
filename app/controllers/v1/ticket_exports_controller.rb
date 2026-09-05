module V1
  class TicketExportsController < ApplicationController
    # GET /v1/tickets/exports?event_id=1
    def index
      unless params[:event_id].present?
        return render json: { error: 'event_id parameter is required' }, status: :unprocessable_content
      end

      begin
        event = Event.find(params[:event_id])
        authorize event, :show?

        exports = ExportLog.where(event_id: event.id, type: 'ticket-list')
                          .order(created_at: :desc)

        render json: exports.as_json(
          only: [:id, :type, :created_at, :updated_at],
          include: {
            event: { only: [:id, :title] }
          }
        ), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Event not found' }, status: :not_found
      rescue Pundit::NotAuthorizedError
        render json: { error: 'Not authorized to view exports for this event' }, status: :forbidden
      end
    end

    # GET /v1/tickets/exports/:id
    def show
      begin
        export_log = ExportLog.find(params[:id])
        event = export_log.event

        # Authorization: User must have access to the event
        authorize event, :show?

        # Check if file exists
        unless File.exist?(export_log.sheet_path)
          return render json: { error: 'Export file not found on server' }, status: :not_found
        end

        # Send the file to the client
        send_file(
          export_log.sheet_path,
          filename: File.basename(export_log.sheet_path),
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          disposition: 'attachment'
        )
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Export not found' }, status: :not_found
      rescue Pundit::NotAuthorizedError
        render json: { error: 'Not authorized to download this export' }, status: :forbidden
      end
    end

    # POST /v1/tickets/exports
    def create
      unless params[:event_id].present?
        return render json: { error: 'event_id parameter is required' }, status: :unprocessable_content
      end

      begin
        event = Event.find(params[:event_id])

        # Authorization: User must have access to this event
        authorize event, :show?

        result = TicketExcelService.export(
          params[:event_id],
          from: params[:from].present? ? Date.parse(params[:from]) : nil,
          to: params[:to].present? ? Date.parse(params[:to]) : nil,
          ticket_type_id: params[:ticket_type_id].presence
        )

        success_response(
          data: {
            id: result[:export_log].id,
            type: result[:export_log].type,
            created_at: result[:export_log].created_at,
            event_id: result[:export_log].event_id
          },
          message: 'Export created successfully',
          status: :created
        )
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Event not found' }, status: :not_found
      rescue Pundit::NotAuthorizedError
        render json: { error: 'Not authorized to export tickets for this event' }, status: :forbidden
      rescue StandardError => e
        Rails.logger.error "Ticket export error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        error_response(
          message: 'Export failed',
          errors: [e.message],
          status: :unprocessable_content
        )
      end
    end

  end
end
