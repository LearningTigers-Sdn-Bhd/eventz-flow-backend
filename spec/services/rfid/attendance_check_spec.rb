require 'rails_helper'

RSpec.describe Rfid::AttendanceCheck do
  include ActiveJob::TestHelper

  let(:event) { create(:event, webhook_url: 'https://hooks.example.com/a, https://hooks.example.com/b') }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:actor) { create(:user) }
  let(:base) { Time.zone.parse('2026-10-01T09:00:00Z') }
  let(:now) { base + 30.minutes }
  let(:check) { described_class.new(event, now: now) }
  let!(:keynote) do
    Rfid::Session.create!(event: event, name: 'Keynote', starts_at: base,
                          ends_at: base + 60.minutes, mandatory: true)
  end

  def guest(name, phone: '0123456789', type: ticket_type, checked_in: true)
    create(:ticket, :paid, event: event, ticket_type: type, attendee_name: name, attendee_phone: phone,
                           checked_in: checked_in)
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

  let!(:never) { guest('Never') }
  let!(:inside) { guest('Inside').tap { |t| visit(t, base + 5.minutes, nil) } }
  let!(:outside) { guest('Outside').tap { |t| visit(t, base + 5.minutes, base + 20.minutes) } }
  let!(:no_phone) { guest('Nophone', phone: nil) }
  let!(:no_show) { guest('Noshow', checked_in: false) }

  it 'splits guests into never detected and outside during the live session' do
    groups = check.summary[:groups]

    # the no-show never checked in, so is not "missing"
    expect(groups['never_detected']).to include(total: 2, sendable: 1, no_phone: 1, no_sticker: 2)
    expect(groups['outside_during_session']).to include(total: 1, sendable: 1)
    expect(check.summary[:live_session]).to include(name: 'Keynote')
  end

  it 'narrows every group to the chosen ticket types' do
    vip = create(:ticket_type, event: event, name: 'VIP')
    guest('Vip', type: vip)

    all = described_class.new(event, now: now).summary
    only_vip = described_class.new(event, now: now, ticket_type_ids: [vip.id]).summary
    none = described_class.new(event, now: now, ticket_type_ids: []).summary

    expect(all[:ticket_types].map { |type| type[:name] }).to include('VIP')
    expect(all[:groups]['never_detected'][:total]).to eq(3)
    expect(only_vip[:groups]['never_detected'][:total]).to eq(1)
    expect(none[:groups].values.sum { |group| group[:total] }).to eq(0)
  end

  it 'has no outside group when no session is live' do
    later = described_class.new(event, now: base + 2.hours)

    expect(later.summary[:groups]['outside_during_session']).to include(total: 0)
    expect(later.summary[:live_session]).to be_nil
  end

  it 'fires one webhook per url per reachable guest, records it, and does not resend soon' do
    expect do
      result = check.notify!(reasons: %w[never_detected outside_during_session], actor: actor)
      expect(result).to eq(sent: 2, skipped_no_phone: 1, skipped_recent: 0)
    end.to have_enqueued_job(WebhookSenderJob).exactly(4).times

    expect(event.rfid_corrections.where(kind: 'attendance_notice').pluck(:ticket_id))
      .to contain_exactly(never.id, outside.id)
    expect(WebhookSenderJob).to have_been_enqueued.with(
      'https://hooks.example.com/a',
      hash_including(event_type: 'rfid.attendance_check',
                     attendance_check: { reason: 'never_detected', session: nil })
    )

    again = described_class.new(event, now: now).notify!(reasons: %w[never_detected], actor: actor)
    expect(again).to eq(sent: 0, skipped_no_phone: 1, skipped_recent: 1)
  end

  it 'lets a notified guest be hard-deleted, taking its notice with it' do
    check.notify!(reasons: %w[never_detected], actor: actor)

    expect { never.delete }.not_to raise_error
    expect(event.rfid_corrections.where(kind: 'attendance_notice', ticket_id: never.id)).to be_empty
  end
end
