require 'rails_helper'

# Plan 5 Task 6: the visit projection. Visits are derived from accepted
# observations, ordered by capture time, and are rebuildable — the same facts
# in any delivery order must produce the same rows.
RSpec.describe Rfid::Visits do
  let(:event) { create(:event, use_api_access: true) }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:ticket) do
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                       attendee_name: 'Ahmad Bin Ali',
                                       check_in_at: Time.zone.parse('2026-09-26T08:00:00Z'))
  end
  let(:tag) { '3412CDAB500104E0' }
  let(:gate) do
    Rfid::Station.create!(event: event, station_key: 'gate-1', kind: 'gate')
  end
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }

  def bind(at: base - 1.hour)
    Rfid::Binding.create!(event: event, ticket: ticket, ticket_public_id: ticket.public_id,
                          ticket_name: ticket.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: tag, tag_key: tag, mode: 'bind', captured_at: at,
                          operation_id: SecureRandom.uuid)
  end

  def reading(role, at, delivery: SecureRandom.uuid)
    Rfid::Observe::Item.new(delivery_id: delivery, role: role, protocol: 'iso15693',
                            uid_raw_hex: tag, tag_key: tag, payload_hex: nil,
                            payload_public_id: nil, device_direction_raw: nil,
                            device_time_raw_hex: nil, device_record_seq: nil, flags_raw: nil,
                            captured_at: at)
  end

  def deliver(items)
    Rfid::Observe.call(event: event, station: gate, items: items)
  end

  def visits
    event.rfid_visits.order(:entry_at).to_a
  end

  before { bind }

  it 'closes a visit with the matching exit and reports the duration' do
    deliver([reading('entry', base), reading('exit', base + 30.minutes)])

    expect(visits.length).to eq(1)
    visit = visits.sole
    expect(visit).to have_attributes(ticket_id: ticket.id, entry_at: base,
                                     exit_at: base + 30.minutes, manual: false)
    expect(visit.open?).to be(false)
    expect(visit.duration_seconds).to eq(30 * 60)
  end

  it 'keeps the first entry when the guest is read in again while open' do
    second_entry = reading('entry', base + 5.minutes)
    deliver([reading('entry', base), second_entry])

    expect(visits.length).to eq(1)
    expect(visits[0].entry_at).to eq(base)
    expect(Rfid::Observation.find_by(delivery_id: second_entry.delivery_id).anomalies)
      .to include('repeated_entry')
    expect(Rfid::Observation.find_by(delivery_id: second_entry.delivery_id).original_response['anomalies'])
      .to eq([])
  end

  it 'clears repeated-entry anomaly after its earlier entry is denied' do
    first = reading('entry', base)
    second = reading('entry', base + 5.minutes)
    deliver([first, second])
    expect(Rfid::Observation.find_by!(delivery_id: second.delivery_id).anomalies)
      .to include('repeated_entry')

    Rfid::Binding.find_by!(event: event, tag_key: tag)
                 .update!(captured_at: base + 1.minute)
    described_class.refresh_locked!(event: event, tag_keys: [tag])
    described_class.rebuild!(event: event)

    expect(Rfid::Observation.find_by!(delivery_id: second.delivery_id).anomalies)
      .not_to include('repeated_entry')
  end

  it 'never creates an entry or a visit for an unmatched exit' do
    exit_reading = reading('exit', base)
    deliver([exit_reading])

    expect(visits).to be_empty
    expect(Rfid::Observation.find_by(delivery_id: exit_reading.delivery_id).anomalies)
      .to include('unmatched_exit')
  end

  it 'starts a new visit after a closed one' do
    deliver([reading('entry', base), reading('exit', base + 10.minutes),
             reading('entry', base + 20.minutes), reading('exit', base + 50.minutes)])

    expect(visits.length).to eq(2)
    expect(visits.map { |v| v.duration_seconds }).to eq([10 * 60, 30 * 60])
  end

  it 'counts an open visit towards headcount but never gives it a duration' do
    deliver([reading('entry', base), reading('exit', base + 1.hour),
             reading('entry', base + 2.hours)])

    expect(visits.length).to eq(2)
    expect(visits.count(&:open?)).to eq(1)
    expect(visits.last.duration_seconds).to be_nil
    expect(visits.last.exit_at).to be_nil
  end

  it 'leaves a visit open across midnight, with no duration invented' do
    crossing = Time.zone.parse('2026-09-26T23:50:00Z')
    deliver([reading('entry', crossing)])

    expect(visits.sole.open?).to be(true)
    expect(visits.sole.duration_seconds).to be_nil
  end

  it 'ignores denied reads and duplicates' do
    denied = reading('exit', base + 5.minutes, delivery: SecureRandom.uuid)
    denied = Rfid::Observe::Item.new(**denied.to_h.merge(uid_raw_hex: '0000000000000009',
                                                         tag_key: '0000000000000009'))
    deliver([reading('entry', base), denied])

    expect(visits.length).to eq(1)
    expect(visits.sole.open?).to be(true)
  end

  it 'produces the same projection whatever order the readings arrived in' do
    early = reading('entry', base)
    late = reading('exit', base + 30.minutes)
    deliver([early, late])
    expected = visits.map { |v| [v.entry_observation_id, v.entry_at, v.exit_at, v.manual] }

    # The same two facts, delivered the other way round on a fresh event.
    other_event = create(:event, use_api_access: true)
    other_station = Rfid::Station.create!(event: other_event, station_key: 'gate-1',
                                                       kind: 'gate')
    other_ticket = create(:ticket, :paid, :checked_in, event: other_event,
                                             ticket_type: create(:ticket_type, event: other_event),
                                             attendee_name: 'Ahmad Bin Ali',
                                             check_in_at: ticket.check_in_at)
    Rfid::Binding.create!(event: other_event, ticket: other_ticket,
                          ticket_public_id: other_ticket.public_id,
                          ticket_name: other_ticket.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: tag, tag_key: tag, mode: 'bind',
                          captured_at: base - 1.hour, operation_id: SecureRandom.uuid)

    shuffled = [late, early].map do |item|
      Rfid::Observe::Item.new(**item.to_h.merge(delivery_id: SecureRandom.uuid))
    end
    Rfid::Observe.call(event: other_event, station: other_station, items: shuffled)

    got = other_event.rfid_visits.order(:entry_at).map do |v|
      [v.entry_at, v.exit_at, v.manual]
    end
    expect(got).to eq(expected.map { |row| row[1..3] })
  end

  it 'rebuilds from the stored observations rather than trusting the old rows' do
    deliver([reading('entry', base)])
    event.rfid_visits.sole.update_columns(entry_at: base + 5.hours, exit_at: base + 6.hours)

    described_class.rebuild!(event: event)

    expect(visits.sole.entry_at).to eq(base)
    expect(visits.sole.exit_at).to be_nil
  end

  it 'does not re-adjudicate every accepted reading on a rebuild' do
    deliver([reading('entry', base)])

    expect(Rfid::Adjudicate).not_to receive(:call)

    described_class.rebuild!(event: event)
  end
end
