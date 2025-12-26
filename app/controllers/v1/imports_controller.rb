module V1
  class ImportsController < ApplicationController
    # POST /v1/imports/tickets
    def tickets
      import_resource(TicketExcelService, 'Ticket')
    end

    # POST /v1/imports/visitors
    def visitors
      import_resource(VisitorExcelService, 'Visitor')
    end

    private

    def import_resource(service_class, resource_name)
      unless current_user
        return render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      unless params[:file].present?
        return render json: { error: 'No file provided' }, status: :unprocessable_content
      end

      begin
        dry_run = ActiveModel::Type::Boolean.new.cast(params[:dry_run])
        full = ActiveModel::Type::Boolean.new.cast(params[:full])
        no_label = ActiveModel::Type::Boolean.new.cast(params[:no_label])
        results = service_class.import(params[:file], dry_run: dry_run, full: full, no_label: no_label)

        total = results[:created][:count] + (results[:updated][:count] || 0) + results[:skipped][:count]

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
        Rails.logger.error "#{resource_name} import error: #{e.message}"
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
