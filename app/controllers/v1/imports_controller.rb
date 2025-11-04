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
        full = ActiveModel::Type::Boolean.new.cast(params[:full])
        results = TicketExcelService.import(params[:file], dry_run: dry_run, full: full)

        # Calculate total
        total = results[:created][:count] + (results[:updated][:count] || 0) + results[:skipped][:count]

        # Transform response to match new structure
        response_data = {
          total: total,
          created: {
            count: results[:created][:count],
            data: results[:created][:data]
          },
          skipped: {
            count: results[:skipped][:count],
            data: results[:skipped][:data]
          },
          errors: {
            count: results[:errors][:count],
            data: results[:errors][:data]
          }
        }

        # Add optional fields if present
        if results[:updated][:count] > 0
          response_data[:updated] = {
            count: results[:updated][:count],
            data: results[:updated][:data]
          }
        end

        if results[:duplicates_in_file][:count] > 0
          response_data[:duplicates_in_file] = {
            count: results[:duplicates_in_file][:count],
            data: results[:duplicates_in_file][:data]
          }
        end

        success_response(
          data: response_data,
          message: "Import completed: #{total} total processed (#{results[:created][:count]} created#{results[:updated][:count] > 0 ? ", #{results[:updated][:count]} updated" : ""}, #{results[:skipped][:count]} skipped)",
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
