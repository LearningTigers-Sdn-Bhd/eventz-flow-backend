require 'rails_helper'
require Rails.root.join('db/migrate/20260827000003_backfill_scan_logs.rb')

RSpec.describe BackfillScanLogs do
  let(:event) { create(:event) }
  let(:staff) { create(:user) }

  before { ScanLog.delete_all }

  it 'creates one row per checked-in ticket, tagged by scanner presence' do
    staff_scanned = create(:ticket, event: event, checked_in: true,
                                    check_in_at: 3.days.ago, scanned_by_id: staff.id, status: :scanned)
    self_scanned = create(:ticket, event: event, checked_in: true,
                                   check_in_at: 2.days.ago, scanned_by_id: nil, status: :scanned)
    create(:ticket, event: event, checked_in: false)

    described_class.new.up

    expect(ScanLog.count).to eq(2)

    staff_log = ScanLog.for_scannable(staff_scanned).sole
    expect(staff_log.source).to eq('staff_scan')
    expect(staff_log.scanned_by_id).to eq(staff.id)
    expect(staff_log.scanned_at).to be_within(1.second).of(staff_scanned.check_in_at)
    expect(staff_log.event_location_id).to be_nil

    expect(ScanLog.for_scannable(self_scanned).sole.source).to eq('self_check_in')
  end

  it 'falls back to updated_at when check_in_at is missing' do
    ticket = create(:ticket, event: event, checked_in: true, check_in_at: nil, status: :scanned)

    described_class.new.up

    expect(ScanLog.for_scannable(ticket).sole.scanned_at)
      .to be_within(1.second).of(ticket.updated_at)
  end

  it 'covers visitors as well as tickets' do
    visitor = create(:visitor, event: event, checked_in: true, check_in_at: 1.day.ago)

    described_class.new.up

    expect(ScanLog.for_scannable(visitor).sole.scannable_type).to eq('Visitor')
  end
end
