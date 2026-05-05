require 'rails_helper'

RSpec.describe TicketDayIndexResolver do
  describe '.current_day_index' do
    let(:event) do
      create(:event, start_date: Date.new(2026, 8, 10), end_date: Date.new(2026, 8, 12))
    end

    it 'returns 1 on the first event day' do
      now = Time.utc(2026, 8, 10, 2, 0, 0)

      expect(described_class.current_day_index(event, now: now)).to eq(1)
    end

    it 'returns the matching day index during the event' do
      now = Time.utc(2026, 8, 11, 2, 0, 0)

      expect(described_class.current_day_index(event, now: now)).to eq(2)
    end

    it 'returns nil before the event date range in Asia/Kuala_Lumpur' do
      now = Time.utc(2026, 8, 9, 15, 59, 59)

      expect(described_class.current_day_index(event, now: now)).to be_nil
    end

    it 'returns nil after the event date range in Asia/Kuala_Lumpur' do
      now = Time.utc(2026, 8, 12, 16, 0, 1)

      expect(described_class.current_day_index(event, now: now)).to be_nil
    end
  end
end
