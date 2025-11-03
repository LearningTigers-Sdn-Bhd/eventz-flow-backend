module V1
  class ImportsController < ApplicationController
    # POST /v1/imports/tickets
    def tickets
      # Authorization: User must be authenticated
      unless current_user
        return render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      # Validate file upload
      unless params[:file].present?
        return render json: { error: 'No file provided' }, status: :unprocessable_content
      end

      begin
        dry_run = ActiveModel::Type::Boolean.new.cast(params[:dry_run])
        results = TicketExcelService.import(params[:file], dry_run: dry_run)

        success_response(
          data: results,
          message: "Import completed: #{results[:created]} created, #{results[:updated]} updated, #{results[:skipped]} skipped",
          status: :ok
        )
      rescue StandardError => e
        Rails.logger.error "Ticket import error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        error_response(
          message: 'Import failed',
          errors: [e.message],
          status: :unprocessable_content
        )
      end
    end
  end
end
