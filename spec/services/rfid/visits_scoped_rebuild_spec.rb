require 'rails_helper'

# The device routes rebuild only the tickets a request touched. The result
# must be exactly what a full-event rebuild would have produced, so each test
# builds history through the incremental paths and then checks that a full
# rebuild changes nothing.
RSpec.describe Rfid::Visits do
  let(:event) { create(:event, use_api_access: true) }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:station) { Rfid::Station.create!(event: event, station_key: 'gate-1', kind: 'gate') }
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }

  def guest(name)
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                       attendee_name: name, check_in_at: base - 1.hour)
  end

  def bind(target, uid)
    Rfid::Binding.create!(event: event, ticket: target, ticket_public_id: target.public_id,
                          ticket_name: target.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: uid, tag_key: uid, mode: 'bind',
                          captured_at: base - 1.hour, operation_id: SecureRandom.uuid)
  end

  def reading(role, at, uid)
    Rfid::Observe::Item.new(delivery_id: SecureRandom.uuid, role: role, protocol: 'iso15693',
                            uid_raw_hex: uid, tag_key: uid, payload_hex: nil,
                            payload_public_id: nil, device_direction_raw: nil,
                            device_time_raw_hex: nil, device_record_seq: nil, flags_raw: nil,
                            captured_at: at)
  end

  def deliver(*items)
    Rfid::Observe.call(event: event, station: station, items: items)
  end

  def snapshot
    visits = event.rfid_visits.order(:entry_at, :ticket_id).map do |visit|
      visit.attributes.slice('ticket_id', 'entry_observation_id', 'exit_observation_id',
                             'entry_at', 'exit_at', 'manual', 'anomalies', 'correction_id')
    end
    readings = event.rfid_observations.order(:id).map do |row|
      [row.id, row.outcome, row.anomalies, row.ticket_id]
    end
    { visits: visits, readings: readings }
  end

  def expect_full_rebuild_to_change_nothing
    before = snapshot
    described_class.rebuild!(event: event)
    expect(snapshot).to eq(before)
  end

  it 'matches a full rebuild for interleaved batches across tickets' do
    tags = %w[AA00000000000001 AA00000000000002 AA00000000000003]
    tags.each_with_index { |uid, i| bind(guest("Guest #{i}"), uid) }

    deliver(reading('entry', base, tags[0]), reading('entry', base + 1.minute, tags[1]))
    deliver(reading('exit', base + 10.minutes, tags[0]), reading('entry', base + 11.minutes, tags[2]))
    # repeated entry, unmatched exit, then a normal visit on a third ticket
    deliver(reading('entry', base + 20.minutes, tags[1]), reading('exit', base + 25.minutes, tags[2]),
            reading('exit', base + 26.minutes, tags[2]))
    deliver(reading('entry', base + 30.minutes, tags[0]))

    expect(event.rfid_visits.count).to be >= 4
    expect_full_rebuild_to_change_nothing
  end

  it 'matches a full rebuild when readings arrive out of order' do
    uid = 'BB00000000000001'
    bind(guest('Late Arrival'), uid)

    deliver(reading('exit', base + 10.minutes, uid))
    deliver(reading('entry', base, uid))

    expect(event.rfid_visits.sole.exit_at).to eq(base + 10.minutes)
    expect_full_rebuild_to_change_nothing
  end

  it 'rebuilds the ticket a late binding explains and nothing else' do
    other_uid = 'CC00000000000001'
    late_uid = 'CC00000000000002'
    bind(guest('Other'), other_uid)
    late_guest = guest('Late Binding')

    deliver(reading('entry', base, other_uid), reading('entry', base, late_uid))
    expect(event.rfid_visits.pluck(:ticket_id)).not_to include(late_guest.id)

    bind(late_guest, late_uid)
    described_class.reconcile_locked!(event: event, tag_key: late_uid)

    expect(event.rfid_visits.where(ticket_id: late_guest.id).count).to eq(1)
    expect_full_rebuild_to_change_nothing
  end

  it 'moves readings off the old ticket when a binding is revoked' do
    uid = 'DD00000000000001'
    owner = guest('Owner')
    binding = bind(owner, uid)
    deliver(reading('entry', base, uid))
    expect(event.rfid_visits.where(ticket_id: owner.id).count).to eq(1)

    binding.destroy!
    described_class.reconcile_locked!(event: event, tag_key: uid, ticket_id: owner.id)

    expect(event.rfid_visits.where(ticket_id: owner.id)).to be_empty
    expect_full_rebuild_to_change_nothing
  end

  it 'does nothing for an empty ticket scope' do
    uid = 'EE00000000000001'
    bind(guest('Idle'), uid)
    deliver(reading('entry', base, uid))

    expect { described_class.rebuild!(event: event, ticket_ids: []) }
      .not_to(change { snapshot })
  end

  it 'leaves other tickets untouched when scoped to one' do
    a_uid = 'FF00000000000001'
    b_uid = 'FF00000000000002'
    a = guest('A')
    bind(a, a_uid)
    bind(guest('B'), b_uid)
    deliver(reading('entry', base, a_uid), reading('entry', base, b_uid))

    event.rfid_visits.where.not(ticket_id: a.id).update_all(ticket_name: 'sentinel')
    described_class.rebuild!(event: event, ticket_ids: [a.id])

    expect(event.rfid_visits.where.not(ticket_id: a.id).pluck(:ticket_name)).to eq(['sentinel'])
  end
end
