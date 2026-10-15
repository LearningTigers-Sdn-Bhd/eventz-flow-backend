module V1
  module Rfid
    # POST /v1/rfid/desk_scans
    #
    # One check-in per operation, replayed exactly. The scanner is a keyboard
    # wedge, so the body is a plain JSON object and every field is validated
    # before anything is written.
    class DeskScansController < BaseController
      def create
        body = parsed_body
        request = ::Rfid::DeskScan::Request.new(
          public_id: uuid_field(body, 'public_id'),
          operation_id: uuid_field(body, 'operation_id'),
          captured_at: time_field(body, 'captured_at')
        )

        status, payload = ::Rfid::DeskScan.call(event: rfid_event, request: request)
        render json: payload, status: status
      end
    end
  end
end
