require 'rails_helper'

RSpec.describe ScanLog, type: :model do
  let(:event) { create(:event) }
  let(:ticket) { create(:ticket, event: event) }

  it 'is valid with the minimum attributes' do
    log = described_class.new(event: event, scannable: ticket,
                              scanned_at: Time.current, source: :staff_scan)
    expect(log).to be_valid
  end

  it 'requires scanned_at' do
    log = described_class.new(event: event, scannable: ticket, source: :staff_scan)
    expect(log).not_to be_valid
    expect(log.errors[:scanned_at]).to be_present
  end

  describe '.for_scannable' do
    it 'returns only rows for that record' do
      mine = create(:scan_log, event: event, scannable: ticket)
      create(:scan_log, event: event, scannable: create(:ticket, event: event))

      expect(described_class.for_scannable(ticket)).to contain_exactly(mine)
    end
  end

  describe '.on_date' do
    it 'returns only rows scanned on that calendar date' do
      today = create(:scan_log, event: event, scannable: ticket,
                               scanned_at: Time.zone.now.change(hour: 9))
      create(:scan_log, event: event, scannable: ticket, scanned_at: 1.day.ago)

      expect(described_class.on_date(Time.zone.today)).to contain_exactly(today)
    end
  end
end
