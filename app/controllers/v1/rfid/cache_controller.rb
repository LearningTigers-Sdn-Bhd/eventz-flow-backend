module V1
  module Rfid
    # GET /v1/rfid/cache
    #
    # A full snapshot every time. RfiDex's cache has no tombstone contract, so
    # `since` cannot produce a partial delta without losing revoked stickers
    # and removed tickets; the parameter is accepted and ignored deliberately.
    #
    # Every non-deleted ticket is listed, invalid ones as `valid: false`, so an
    # offline desk can refuse an unpaid or cancelled guest without asking.
    class CacheController < BaseController
      def show
        render json: {
          tickets: rfid_event.tickets.includes(:ticket_type).order(:public_id)
                           .map { |ticket| ::Rfid::Wire.ticket(ticket) },
          bindings: rfid_event.rfid_bindings.active.order(:id)
                            .map { |binding| ::Rfid::Wire.binding_info(binding) },
          revoked_tag_keys: revoked_tag_keys,
          server_time: ::Rfid::Wire.time(Time.current)
        }, status: :ok
      end

      private

      # A sticker that was revoked and is not linked to anything else. A key
      # that was revoked and then reused is active again, not revoked.
      def revoked_tag_keys
        bindings = rfid_event.rfid_bindings
        active = bindings.active.pluck(:tag_key).to_set

        bindings.where.not(revoked_at: nil).pluck(:tag_key)
                .uniq.reject { |tag_key| active.include?(tag_key) }
                .sort
      end
    end
  end
end
