# The RfiDex device wire format, exactly as `rfidex-core::contract` defines it.
#
# Two rules this module exists to keep in one place:
#   * every field of a DTO is always present, `null` when absent, because the
#     Rust structs deserialize the full shape;
#   * contact values are masked here, from the same normalized columns search
#     matches, so a hint can never show a value a search cannot find.
module Rfid
  module Wire
    module_function

    # `TicketSummary`
    def ticket(ticket)
      {
        public_id: ticket.public_id,
        name: ticket.attendee_name,
        ticket_type: ticket.ticket_type&.name.to_s,
        valid: valid?(ticket),
        checked_in: ticket.checked_in
      }
    end

    # `TicketSearchItem`: the summary plus the masked hints.
    def search_item(ticket)
      summary = ticket(ticket)
      summary.merge(
        checked_in_at: time(ticket.check_in_at),
        email_hint: mask_email(ticket.attendee_email_norm),
        phone_hint: mask_phone(ticket.attendee_phone_norm)
      )
    end

    # `BindingInfo`
    def binding_info(binding)
      return nil if binding.nil?

      {
        id: binding.id,
        public_id: binding.ticket_public_id,
        protocol: binding.protocol,
        uid_raw_hex: binding.uid_raw_hex,
        tag_key: binding.tag_key,
        mode: binding.mode
      }
    end

    # `ErrorBody`: all four keys, holder/binding null unless they are known.
    def error(code, message, holder: nil, binding: nil)
      {
        error: code,
        message: message,
        holder: holder.nil? ? nil : ticket(holder),
        binding: binding_info(binding)
      }
    end

    # Paid and not cancelled — the same rule the check-in page and the station
    # use. A refunded ticket is not `paid?` any more, so it is invalid too.
    def valid?(ticket)
      ticket.paid? && !ticket.canceled?
    end

    def time(value)
      value&.utc&.iso8601(6)
    end

    # --- tag identity ---------------------------------------------------------
    # Raw UID bytes are kept exactly as the device reported them; `tag_key` is
    # the only place a station's byte-order rule is applied, and it mirrors
    # `rfidex-core::tag` so a key computed here is the client's key.

    def hex_upper(bytes)
      bytes.map { |byte| format('%02X', byte) }.join
    end

    # Nil for anything that is not an even-length run of hex digits, so callers
    # can answer a typed `malformed` instead of guessing bytes.
    def parse_hex(value)
      text = value.to_s.strip
      return nil if text.empty? || !text.length.even? || !text.match?(/\A[0-9a-fA-F]+\z/)

      [text].pack('H*').bytes
    end

    def normalize_uid(uid_raw_hex)
      bytes = parse_hex(uid_raw_hex)
      bytes && hex_upper(bytes)
    end

    # `as_is` unless the station was explicitly verified and flipped.
    def tag_key(uid_raw_hex, uid_rule)
      bytes = parse_hex(uid_raw_hex)
      return nil if bytes.nil?

      hex_upper(uid_rule == 'reversed' ? bytes.reverse : bytes)
    end

    # --- sticker payload ------------------------------------------------------
    # `rfidex-core::codec` v1: 'R' 'X' | version | CRC-8 (poly 0x07) | 16 bytes
    # of ticket public id. A decoded id is an identifier, never a credential.

    PAYLOAD_LEN = 20
    PAYLOAD_MAGIC = [0x52, 0x58].freeze
    PAYLOAD_VERSION = 1

    def crc8(bytes)
      bytes.reduce(0) do |crc, byte|
        crc ^= byte
        8.times do
          crc = (crc & 0x80).zero? ? (crc << 1) & 0xFF : ((crc << 1) ^ 0x07) & 0xFF
        end
        crc
      end
    end

    # The ticket public id a payload names, or nil when the bytes are not a
    # valid v1 payload. Nil never authorizes anything by itself.
    def decode_payload(payload_hex)
      bytes = parse_hex(payload_hex)
      return nil if bytes.nil? || bytes.length < PAYLOAD_LEN

      body = bytes[0, PAYLOAD_LEN]
      return nil if body.all?(&:zero?) || body.all? { |byte| byte == 0xFF }
      return nil unless body[0, 2] == PAYLOAD_MAGIC && body[2] == PAYLOAD_VERSION
      return nil unless crc8(body[4, 16]) == body[3]

      uuid_from_bytes(body[4, 16])
    end

    def uuid_from_bytes(bytes)
      hex = bytes.map { |byte| format('%02x', byte) }.join
      "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
    end

    # At most two visible characters of the local part, and never all of it: a
    # one-character local part shows none.
    def mask_email(value)
      return nil if value.blank?

      local, domain = value.split('@', 2)
      if domain.nil?
        local = value
        domain = ''
      end
      visible = [local.length - 1, 2].min
      visible = 0 if visible.negative?
      "#{local[0, visible]}***@#{domain}"
    end

    # At most four trailing digits, and never the whole number.
    def mask_phone(value)
      return nil if value.blank?

      digits = value.gsub(/\D/, '')
      return nil if digits.empty?

      shown = [digits.length - 1, 4].min
      shown = 0 if shown.negative?
      "•••• #{shown.zero? ? '' : digits[-shown, shown]}"
    end
  end
end
