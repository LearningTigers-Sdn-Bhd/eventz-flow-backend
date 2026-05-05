require 'rails_helper'

RSpec.describe TicketDayValidationService do
  describe '.call' do
    let(:event) do
      create(:event, start_date: Date.new(2026, 8, 10), end_date: Date.new(2026, 8, 12))
    end
    let(:ticket_type) { create(:ticket_type, event: event, valid_day_indexes: [2, 3]) }
    let(:ticket) { create(:ticket, event: event, ticket_type: ticket_type) }

    it 'fails with wrong_event when scanner event does not match ticket event' do
      other_event = create(:event)

      result = described_class.call(ticket: ticket, scanner_event_id: other_event.id, now: Time.utc(2026, 8, 11, 2, 0, 0))

      expect(result).not_to be_ok
      expect(result.invalid_reason).to eq('wrong_event')
    end

    it 'fails with outside_event_days when now is outside event date range' do
      result = described_class.call(ticket: ticket, scanner_event_id: event.id, now: Time.utc(2026, 8, 9, 12, 0, 0))

      expect(result).not_to be_ok
      expect(result.invalid_reason).to eq('outside_event_days')
    end

    it 'fails with wrong_day and returns allowed_day_indexes when ticket is not valid for current day' do
      result = described_class.call(ticket: ticket, scanner_event_id: event.id, now: Time.utc(2026, 8, 10, 2, 0, 0))

      expect(result).not_to be_ok
      expect(result.invalid_reason).to eq('wrong_day')
      expect(result.allowed_day_indexes).to eq([2, 3])
      expect(result.current_day_index).to eq(1)
    end

    it 'fails with already_checked_in_today when a scan log exists for current day' do
      create(:ticket_scan_log, ticket: ticket, event: event, day_index: 2)

      result = described_class.call(ticket: ticket, scanner_event_id: event.id, now: Time.utc(2026, 8, 11, 2, 0, 0))

      expect(result).not_to be_ok
      expect(result.invalid_reason).to eq('already_checked_in_today')
      expect(result.current_day_index).to eq(2)
    end

    it 'passes when ticket type valid_day_indexes is nil (all event days)' do
      ticket_type.update!(valid_day_indexes: nil)

      result = described_class.call(ticket: ticket, scanner_event_id: event.id, now: Time.utc(2026, 8, 10, 2, 0, 0))

      expect(result).to be_ok
      expect(result.invalid_reason).to be_nil
      expect(result.current_day_index).to eq(1)
      expect(result.allowed_day_indexes).to eq([1, 2, 3])
    end
  end
end
