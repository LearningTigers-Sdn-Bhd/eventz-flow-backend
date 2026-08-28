require 'rails_helper'

RSpec.describe ScanGate do
  let(:event) { create(:event, multiple_scans: false) }
  let(:ticket) { create(:ticket, :paid, event: event) }
  let(:main_hall) { create(:event_location, event: event, name: 'Main Hall') }
  let(:vip) { create(:event_location, event: event, name: 'VIP Lounge') }

  def log(at: Time.current, location: nil)
    create(:scan_log, event: event, scannable: ticket, scanned_at: at, event_location: location)
  end

  context 'when multiple_scans is off' do
    it 'allows the first scan' do
      expect(described_class.call(ticket)).to eq(:allowed)
    end

    it 'blocks any later scan with the earliest row' do
      first = log(at: 2.hours.ago)
      log(at: 1.hour.ago)

      expect(described_class.call(ticket)).to eq(first)
    end
  end

  context 'when mode is unlimited' do
    before { event.update!(multiple_scans: true, multiple_scan_mode: :unlimited) }

    it 'never blocks' do
      log(at: 1.minute.ago)
      expect(described_class.call(ticket)).to eq(:allowed)
    end
  end

  context 'when mode is per_location' do
    before { event.update!(multiple_scans: true, multiple_scan_mode: :per_location) }

    it 'blocks a repeat at the same location today' do
      existing = log(at: Time.zone.now.change(hour: 9), location: main_hall)
      expect(described_class.call(ticket, location: main_hall)).to eq(existing)
    end

    it 'allows a different location on the same day' do
      log(at: Time.zone.now.change(hour: 9), location: main_hall)
      expect(described_class.call(ticket, location: vip)).to eq(:allowed)
    end

    it 'allows the same location on a later day' do
      log(at: 1.day.ago, location: main_hall)
      expect(described_class.call(ticket, location: main_hall)).to eq(:allowed)
    end

    it 'treats a nil location as its own bucket' do
      log(at: Time.zone.now.change(hour: 9), location: main_hall)
      expect(described_class.call(ticket, location: nil)).to eq(:allowed)
    end
  end

  context 'when mode is per_day' do
    before { event.update!(multiple_scans: true, multiple_scan_mode: :per_day) }

    it 'blocks a second scan today regardless of location' do
      existing = log(at: Time.zone.now.change(hour: 9), location: main_hall)
      expect(described_class.call(ticket, location: vip)).to eq(existing)
    end

    it 'allows a scan on the next day' do
      log(at: 1.day.ago, location: main_hall)
      expect(described_class.call(ticket, location: main_hall)).to eq(:allowed)
    end
  end

  context 'with a ticket that has not been paid for' do
    let(:pending_ticket) { create(:ticket, event: event, payment_status: :pending) }

    it 'blocks the scan regardless of check-in history' do
      expect(described_class.call(pending_ticket)).to eq(:unpaid)
    end

    it 'record! returns :unpaid and writes nothing' do
      status, log = described_class.record!(pending_ticket, by: create(:user))

      expect(status).to eq(:unpaid)
      expect(log).to be_nil
      expect(pending_ticket.reload.checked_in).to be false
      expect(ScanLog.for_scannable(pending_ticket)).to be_empty
    end
  end

  context 'with a visitor' do
    let(:visitor) { create(:visitor, event: event) }

    it 'blocks a repeat when multiple_scans is off' do
      existing = create(:scan_log, event: event, scannable: visitor, scanned_at: 1.hour.ago)
      expect(described_class.call(visitor)).to eq(existing)
    end
  end

  describe '.record!' do
    let(:staff) { create(:user) }

    context 'on the first scan' do
      it 'creates a log and stamps the denormalised columns' do
        status, log = described_class.record!(ticket, by: staff, location: main_hall)

        expect(status).to eq(:ok)
        expect(log).to be_persisted
        expect(log.event_location).to eq(main_hall)
        expect(log.source).to eq('staff_scan')

        ticket.reload
        expect(ticket.checked_in).to be true
        expect(ticket.check_in_at).to be_within(1.second).of(log.scanned_at)
        expect(ticket.scanned_by_id).to eq(staff.id)
        expect(ticket.status).to eq('scanned')
      end
    end

    context 'on an allowed re-scan' do
      before { event.update!(multiple_scans: true, multiple_scan_mode: :unlimited) }

      it 'appends a log but leaves check_in_at at the first scan' do
        _, first = described_class.record!(ticket, by: staff, location: main_hall)
        original_check_in = ticket.reload.check_in_at

        travel_to(1.hour.from_now) do
          status, second = described_class.record!(ticket, by: staff, location: vip)
          expect(status).to eq(:ok)
          expect(second.id).not_to eq(first.id)
        end

        expect(ticket.reload.check_in_at).to be_within(1.second).of(original_check_in)
        expect(ScanLog.for_scannable(ticket).count).to eq(2)
      end
    end

    context 'on a blocked re-scan' do
      it 'returns :blocked and writes nothing' do
        _, first = described_class.record!(ticket, by: staff)

        status, blocker = described_class.record!(ticket, by: staff)

        expect(status).to eq(:blocked)
        expect(blocker).to eq(first)
        expect(ScanLog.for_scannable(ticket).count).to eq(1)
      end
    end

    it 'records a null scanner for self check-in' do
      status, log = described_class.record!(ticket, by: nil, source: :self_check_in)

      expect(status).to eq(:ok)
      expect(log.scanned_by_id).to be_nil
      expect(log.source).to eq('self_check_in')
      expect(ticket.reload.scanned_by_id).to be_nil
    end
  end

  describe '.undo!' do
    let(:staff) { create(:user) }

    before { event.update!(multiple_scans: true, multiple_scan_mode: :unlimited) }

    it 'removes the newest row and re-points check_in_at at the earliest survivor' do
      _, first = described_class.record!(ticket, by: staff, at: 2.hours.ago)
      _, second = described_class.record!(ticket, by: staff, at: 1.hour.ago)

      expect(described_class.undo!(ticket)).to be true

      ticket.reload
      expect(ScanLog.for_scannable(ticket)).to contain_exactly(first)
      expect(ticket.checked_in).to be true
      expect(ticket.check_in_at).to be_within(1.second).of(first.scanned_at)
      expect(ScanLog.where(id: second.id)).to be_empty
    end

    it 'resets the record when the last row is removed' do
      described_class.record!(ticket, by: staff)

      expect(described_class.undo!(ticket)).to be true

      ticket.reload
      expect(ticket.checked_in).to be false
      expect(ticket.check_in_at).to be_nil
      expect(ticket.scanned_by_id).to be_nil
      expect(ticket.status).to eq('purchased')
    end

    it 'returns false when there is nothing to undo' do
      expect(described_class.undo!(ticket)).to be false
    end

    it 'fires the ticket after_commit callbacks (e.g. the outbound webhook)' do
      # Regression guard: update_columns would silently skip after_commit,
      # so external systems (door displays, printers) never learn a ticket
      # was unscanned.
      webhooked_event = create(:event, multiple_scans: true, multiple_scan_mode: :unlimited,
                                       webhook_url: 'https://example.com/webhook')
      webhooked_ticket = create(:ticket, :paid, event: webhooked_event)
      described_class.record!(webhooked_ticket, by: staff)

      expect { described_class.undo!(webhooked_ticket) }
        .to have_enqueued_job(WebhookSenderJob)
    end
  end

  describe 'concurrent scans' do
    let(:staff) { create(:user) }

    it 'writes exactly one log when two threads scan simultaneously' do
      ticket # create before the threads so both see the same row

      results = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            described_class.record!(ticket, by: staff)
          end
        end
      end.map(&:value)

      expect(results.count { |status, _| status == :ok }).to eq(1)
      expect(results.count { |status, _| status == :blocked }).to eq(1)
      expect(ScanLog.for_scannable(ticket).count).to eq(1)
    end
  end
end
