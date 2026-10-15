require 'rails_helper'

# Plan 5 Task 7: the report reads current adjudication and the visit
# projection, never the raw device replies.
RSpec.describe Rfid::Report do
  let(:event) { create(:event, use_api_access: true) }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:first) do
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                       attendee_name: 'Ahmad Bin Ali',
                                       check_in_at: Time.zone.parse('2026-09-26T08:00:00Z'))
  end
  let(:second) do
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                       attendee_name: 'Siti Nurhaliza',
                                       check_in_at: Time.zone.parse('2026-09-26T08:00:00Z'))
  end
  let(:station) do
    Rfid::Station.create!(event: event, station_key: 'gate-1', kind: 'gate')
  end
  let(:tag) { '3412CDAB500104E0' }
  let(:other_tag) { 'AABBCCDD00112233' }
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }
  let(:report) { described_class.new(event) }

  def bind(target, uid: tag, at: base - 1.hour)
    Rfid::Binding.create!(event: event, ticket: target, ticket_public_id: target.public_id,
                          ticket_name: target.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: uid, tag_key: uid, mode: 'bind', captured_at: at,
                          operation_id: SecureRandom.uuid)
  end

  def reading(role, at, uid: tag, delivery: SecureRandom.uuid)
    Rfid::Observe::Item.new(delivery_id: delivery, role: role, protocol: 'iso15693',
                            uid_raw_hex: uid, tag_key: uid, payload_hex: nil,
                            payload_public_id: nil, device_direction_raw: nil,
                            device_time_raw_hex: nil, device_record_seq: nil, flags_raw: nil,
                            captured_at: at)
  end

  def deliver(items)
    Rfid::Observe.call(event: event, station: station, items: items)
  end

  before do
    bind(first)
    bind(second, uid: other_tag)
  end

  it 'summarises attendance, open visits and anomalies' do
    deliver([reading('entry', base), reading('exit', base + 10.minutes),
             reading('entry', base + 1.hour, uid: other_tag),
             reading('exit', base + 2.hours)])

    summary = report.summary

    expect(summary[:headcount]).to eq(1)
    expect(summary[:open_visits]).to eq(1)
    # One visit anomaly: the exit that closed no visit.
    expect(summary[:anomaly_count]).to eq(1)
    expect(summary[:last_observed_at]).to eq(Rfid::Wire.time(base + 2.hours))
  end

  it 'counts registered, checked-in, gate-scanned, inside and outside, and splits missed scans' do
    # first: enters and stays inside. second: enters and leaves (outside).
    # unbound: checked in, no sticker. unread: sticker linked, no gate read.
    # absent: paid, never checked in.
    unbound = create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                                  attendee_name: 'No Sticker',
                                                  check_in_at: base - 1.hour)
    unread = create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                                 attendee_name: 'Not Read',
                                                 check_in_at: base - 1.hour)
    bind(unread, uid: '0000000000000001')
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Absent')
    deliver([reading('entry', base), reading('entry', base, uid: other_tag),
             reading('exit', base + 10.minutes, uid: other_tag)])

    summary = report.summary

    expect(summary).to include(registered: 5, checked_in: 4, not_arrived: 1, gate_scanned: 2,
                               inside: 1, outside: 1, missed_scans: { no_tag: 1, no_read: 1 })
    expect(report.missed_scan_rows(report.missed_scans_scope.to_a).map { |row| [row[:ticket_name], row[:reason]] })
      .to contain_exactly(['No Sticker', 'no_tag'], ['Not Read', 'no_read'])
    expect(report.missed_scans_scope('no_tag').to_a).to eq([unbound])
  end

  it 'reports zero headcount when all visits have ended' do
    deliver([reading('entry', base), reading('exit', base + 10.minutes)])

    expect(report.summary[:headcount]).to eq(0)
    expect(report.summary[:open_visits]).to eq(0)
  end

  it 'lists visits newest first with a duration only when closed' do
    deliver([reading('entry', base), reading('exit', base + 10.minutes),
             reading('entry', base + 1.hour)])

    rows = report.visit_rows(report.visits_scope)

    expect(rows.length).to eq(2)
    expect(rows[0]).to include(ticket_public_id: first.public_id, ticket_name: 'Ahmad Bin Ali',
                               ticket_type: 'Delegate', entry_at: Rfid::Wire.time(base + 1.hour),
                               exit_at: nil, duration_seconds: nil, manual: false)
    expect(rows[1][:duration_seconds]).to eq(600)
    expect(rows[1][:anomalies]).to eq([])
  end

  it 'lists the binding history, active and revoked' do
    old = event.rfid_bindings.find_by(tag_key: tag)
    old.update!(revoked_at: Time.current, revocation_reason: 'moved')

    rows = report.bindings

    expect(rows.map { |row| row[:active] }).to eq([false, true])
    expect(rows[0]).to include(ticket_public_id: first.public_id, ticket_name: 'Ahmad Bin Ali',
                               tag_key: tag, mode: 'bind', revocation_reason: 'moved')
    expect(rows[1][:revoked_at]).to be_nil
  end

  it 'shows a corrected reading with its original and current outcome' do
    # A gate reads before the desk's (offline) binding arrives.
    late_tag = '00000000000000FF'
    late_ticket = create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type,
                                              attendee_name: 'Late Binding',
                                              check_in_at: Time.zone.parse('2026-09-26T08:00:00Z'))
    delivery = SecureRandom.uuid
    deliver([reading('exit', base - 30.minutes, uid: late_tag, delivery: delivery)])
    expect(report.anomaly_observation_row(report.anomaly_observations.find_by(tag_key: late_tag))[:current_outcome])
      .to eq('unknown_tag')

    bind(late_ticket, uid: late_tag, at: base - 1.hour)
    Rfid::Visits.reconcile_locked!(event: event, tag_key: late_tag)

    rows = report.anomaly_observations.map { |row| report.anomaly_observation_row(row) }
    row = rows.find { |candidate| candidate[:tag_key] == late_tag }

    expect(row).to include(current_outcome: 'accepted', role: 'exit')
    expect(Rfid::Observation.find_by(delivery_id: delivery).original_response['outcome'])
      .to eq('unknown_tag')
    expect(row[:captured_at]).to eq(Rfid::Wire.time(base - 30.minutes))
  end

  it 'keeps a manual exit after a rebuild and reports it' do
    deliver([reading('entry', base)])
    visit = event.rfid_visits.sole
    Rfid::Correction.create!(event: event, actor: create(:user, :org_owner),
                             entry_observation: visit.entry_observation, kind: 'manual_exit',
                             exit_at: base + 15.minutes, reason: 'left through the side door',
                             details: { 'entry_observation_id' => visit.entry_observation_id })

    Rfid::Visits.rebuild!(event: event)

    row = report.visit_row(visit.reload)
    expect(row).to include(manual: true, exit_at: Rfid::Wire.time(base + 15.minutes),
                           duration_seconds: 900, anomalies: ['manual_exit'])
    expect(report.anomaly_visits.count).to eq(1)
    expect(report.summary[:anomaly_count]).to eq(1)
  end
end
