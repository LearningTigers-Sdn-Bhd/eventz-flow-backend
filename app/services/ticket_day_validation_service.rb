class TicketDayValidationService
  Result = Struct.new(
    :ok,
    :invalid_reason,
    :current_day_index,
    :allowed_day_indexes,
    keyword_init: true
  ) do
    def ok?
      ok
    end

    def error_payload
      {
        invalid_reason: invalid_reason,
        current_day_index: current_day_index,
        allowed_day_indexes: allowed_day_indexes
      }.compact
    end
  end

  def self.call(ticket:, scanner_event_id:, now: Time.current)
    new(ticket: ticket, scanner_event_id: scanner_event_id, now: now).call
  end

  def initialize(ticket:, scanner_event_id:, now:)
    @ticket = ticket
    @scanner_event_id = scanner_event_id
    @now = now
  end

  def call
    if scanner_event_id.present? && ticket.event_id != scanner_event_id
      return failure('wrong_event')
    end

    current_day_index = TicketDayIndexResolver.current_day_index(ticket.event, now: now)
    return failure('outside_event_days') if current_day_index.nil?

    allowed_day_indexes = resolve_allowed_day_indexes

    unless allowed_day_indexes.include?(current_day_index)
      return failure('wrong_day', current_day_index: current_day_index, allowed_day_indexes: allowed_day_indexes)
    end

    if TicketScanLog.exists?(ticket_id: ticket.id, day_index: current_day_index)
      return failure('already_checked_in_today', current_day_index: current_day_index, allowed_day_indexes: allowed_day_indexes)
    end

    success(current_day_index: current_day_index, allowed_day_indexes: allowed_day_indexes)
  end

  private

  attr_reader :ticket, :scanner_event_id, :now

  def resolve_allowed_day_indexes
    configured = ticket.ticket_type.valid_day_indexes
    return configured.sort if configured.present?

    start_date = ticket.event.start_date.to_date
    end_date = ticket.event.end_date.to_date
    (1..((end_date - start_date).to_i + 1)).to_a
  end

  def success(current_day_index:, allowed_day_indexes:)
    Result.new(ok: true, invalid_reason: nil, current_day_index: current_day_index, allowed_day_indexes: allowed_day_indexes)
  end

  def failure(reason, current_day_index: nil, allowed_day_indexes: nil)
    Result.new(ok: false, invalid_reason: reason, current_day_index: current_day_index, allowed_day_indexes: allowed_day_indexes)
  end
end
