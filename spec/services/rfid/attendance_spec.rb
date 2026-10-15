require 'rails_helper'

RSpec.describe Rfid::Attendance do
  let(:event) { create(:event, rfid_attendance_percent: 80) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:base) { Time.zone.parse('2026-10-01T09:00:00Z') }
  let(:now) { base + 4.hours }
  let(:attendance) { described_class.new(event, now: now) }
  let!(:keynote) do
    Rfid::Session.create!(event: event, name: 'Keynote', starts_at: base,
                          ends_at: base + 100.minutes, mandatory: true)
  end
  let!(:workshop) do
    Rfid::Session.create!(event: event, name: 'Workshop', starts_at: base + 2.hours,
                          ends_at: base + 3.hours, mandatory: false)
  end

  def ticket(name)
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type, attendee_name: name)
  end

  def visit(target, from, to)
    uid = format('%016X', target.id)
    station = Rfid::Station.find_or_create_by!(event: event, station_key: 'gate-1', kind: 'gate')
    Rfid::Binding.create!(event: event, ticket: target, ticket_public_id: target.public_id,
                          ticket_name: target.attendee_name, protocol: 'iso15693',
                          uid_raw_hex: uid, tag_key: uid, mode: 'bind',
                          captured_at: from - 1.hour, operation_id: SecureRandom.uuid)
    items = [reading('entry', from, uid)]
    items << reading('exit', to, uid) if to
    Rfid::Observe.call(event: event, station: station, items: items)
  end

  def reading(role, at, uid)
    Rfid::Observe::Item.new(delivery_id: SecureRandom.uuid, role: role, protocol: 'iso15693',
                            uid_raw_hex: uid, tag_key: uid, payload_hex: nil,
                            payload_public_id: nil, device_direction_raw: nil,
                            device_time_raw_hex: nil, device_record_seq: nil, flags_raw: nil,
                            captured_at: at)
  end

  def feedback(target)
    form = event.feedback_form || FeedbackForm.create!(event: event, title: 'F')
    form.feedback_responses.create!(ticket: target, submitted_at: now)
  end

  it 'counts a guest as attended only at 80% of the session, clipping visits to the window' do
    full = ticket('Full')
    short = ticket('Short')
    visit(full, base - 30.minutes, base + 100.minutes)  # 100 min inside
    visit(short, base + 30.minutes, base + 100.minutes) # 70 of 100 min

    row = attendance.sessions.find { |item| item[:name] == 'Keynote' }

    expect(row).to include(status: 'ended', present: 2, attended: 1, required_seconds: 4800)
  end

  it 'counts an open visit up to now, never past the session end' do
    stays = ticket('Stays')
    visit(stays, base, nil)

    expect(attendance.sessions.find { |item| item[:name] == 'Keynote' }).to include(attended: 1)
  end

  it 'qualifies only guests who met every mandatory session and gave feedback' do
    good = ticket('Good')
    no_form = ticket('Noform')
    late = ticket('Late')
    [good, no_form].each { |guest| visit(guest, base, base + 100.minutes) }
    visit(late, base + 50.minutes, base + 100.minutes)
    feedback(good)

    statuses = attendance.eligibility_rows.to_h { |row| [row[:ticket_name], row[:status]] }

    expect(statuses).to include('Good' => 'qualified', 'Noform' => 'needs_feedback',
                                'Late' => 'not_qualified')
    expect(attendance.eligibility_summary).to include(qualified: 1, needs_feedback: 1, not_qualified: 1,
                                                       required_sessions: 1)
    expect(described_class.qualified_ticket_ids(event)).to eq([good.id])
  end

  it 'lets a staff override waive attendance but still needs feedback, until revoked' do
    left_early = ticket('Early')
    visit(left_early, base + 50.minutes, base + 60.minutes)
    row = -> { described_class.new(event).eligibility_rows.first }
    grant = lambda do |kind|
      Rfid::Correction.create!(event: event, ticket: left_early, kind: kind, reason: 'logistics')
    end

    expect(row.call[:status]).to eq('not_qualified')

    grant.call('cert_override')
    expect(row.call).to include(status: 'needs_feedback', override: include(reason: 'logistics'))

    feedback(left_early)
    expect(row.call[:status]).to eq('qualified')

    grant.call('cert_override_revoked')
    expect(row.call).to include(status: 'not_qualified', override: nil)
  end

  it 'keeps a guest in progress while a mandatory session has not ended' do
    ticket('Waiting')
    live = described_class.new(event, now: base + 10.minutes)

    expect(live.eligibility_rows.first[:status]).to eq('in_progress')
  end

  it 'has no eligibility rows when no session is mandatory' do
    keynote.update!(mandatory: false)

    expect(attendance.eligibility_rows).to eq([])
  end
end
