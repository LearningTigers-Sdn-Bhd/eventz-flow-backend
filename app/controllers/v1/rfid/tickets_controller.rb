module V1
  module Rfid
    # GET /v1/rfid/tickets/search?by=name|email|phone&q=…
    #
    # The fallback for a lost or unreadable QR code. Paid tickets only, at most
    # ten, newest first, one event — and email/phone are masked before they
    # leave the server, because the desk only needs hints to tell two guests
    # with the same name apart.
    class TicketsController < BaseController
      SEARCH_FIELDS = %w[name email phone].freeze
      NAME_MINIMUM = 2
      PHONE_MINIMUM = 4
      RESULT_LIMIT = 10

      def search
        by = params[:by].to_s
        raise MalformedRequest, 'by must be name, email or phone' unless SEARCH_FIELDS.include?(by)
        raise MalformedRequest, 'q is required' if params[:q].nil?

        render json: { tickets: search_tickets(by, params[:q].to_s) }, status: :ok
      end

      private

      def search_tickets(by, value)
        key = normalized_query(by, value)
        return [] if key.nil?

        # `%` and `_` in the guest's own text are literal characters, not
        # wildcards, and the tie order is fixed so two guests created at the
        # same instant always rank the same way.
        rows = case by
               when 'name'
                 rfid_event.tickets.paid.where('attendee_name_norm LIKE ?', "%#{escape_like(key)}%")
               when 'email'
                 rfid_event.tickets.paid.where(attendee_email_norm: key)
               when 'phone'
                 rfid_event.tickets.paid.where('attendee_phone_norm LIKE ?', "%#{escape_like(key)}%")
               end

        rows.includes(:ticket_type).order(created_at: :desc, public_id: :asc).limit(RESULT_LIMIT)
            .map { |ticket| ::Rfid::Wire.search_item(ticket) }
      end

      # The same normalization the stored columns use, with the contract's
      # minima: a query that cannot match anything is answered with an empty
      # list rather than an error.
      def normalized_query(by, value)
        case by
        when 'name'
          key = value.strip.gsub(/\s+/, ' ').downcase
          key.length >= NAME_MINIMUM ? key : nil
        when 'email'
          key = value.strip.downcase
          key.include?('@') ? key : nil
        when 'phone'
          digits = value.gsub(/\D/, '').sub(/\A(?:60|0)/, '')
          digits.length >= PHONE_MINIMUM ? digits : nil
        end
      end

      def escape_like(value)
        ActiveRecord::Base.sanitize_sql_like(value)
      end
    end
  end
end
