require 'rails_helper'

RSpec.describe TicketScanLog, type: :model do
  describe 'associations' do
    it { should belong_to(:ticket) }
    it { should belong_to(:event) }
    it { should belong_to(:scanned_by).class_name('User') }
  end

  describe 'validations' do
    it { should validate_numericality_of(:day_index).only_integer.is_greater_than(0) }
    it { should validate_presence_of(:scanned_at) }
  end

  describe 'per-day uniqueness' do
    let(:ticket) { create(:ticket) }
    let(:event) { ticket.event }

    it 'enforces one scan per ticket per day index' do
      create(:ticket_scan_log, ticket: ticket, event: event, day_index: 1)
      dup = build(:ticket_scan_log, ticket: ticket, event: event, day_index: 1)

      expect(dup).not_to be_valid
      expect(dup.errors[:ticket_id]).to include('has already been taken')
    end

    it 'allows same ticket on another day index' do
      create(:ticket_scan_log, ticket: ticket, event: event, day_index: 1)
      next_day = build(:ticket_scan_log, ticket: ticket, event: event, day_index: 2)

      expect(next_day).to be_valid
    end
  end
end
