require 'rails_helper'

RSpec.describe Rfid::ReportWorkbook do
  let(:event) { create(:event, use_api_access: true, rfid_attendance_percent: 80) }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:station) { Rfid::Station.create!(event: event, station_key: 'gate-1', kind: 'gate', name: 'Main gate') }
  let(:base) { Time.zone.parse('2026-09-26T09:00:00Z') }

  def guest(name)
    create(:ticket, :paid, :checked_in, event: event, ticket_type: ticket_type, attendee_name: name,
                                         check_in_at: base - 1.hour)
  end

  def bind(ticket, uid)
    Rfid::Binding.create!(event: event, ticket: ticket, ticket_public_id: ticket.public_id,
                          ticket_name: ticket.attendee_name, protocol: 'iso15693', uid_raw_hex: uid, tag_key: uid,
                          mode: 'bind', captured_at: base - 2.hours, operation_id: SecureRandom.uuid)
  end

  def scan(uid, role, at)
    item = Rfid::Observe::Item.new(delivery_id: SecureRandom.uuid, role: role, protocol: 'iso15693',
                                   uid_raw_hex: uid, tag_key: uid, payload_hex: nil, payload_public_id: nil,
                                   device_direction_raw: nil, device_time_raw_hex: nil, device_record_seq: nil,
                                   flags_raw: nil, captured_at: at)
    Rfid::Observe.call(event: event, station: station, items: [item])
  end

  def workbook
    file = Tempfile.new(['report', '.xlsx'], binmode: true)
    file.write(described_class.new(event, now: base + 3.hours).call)
    file.flush
    Roo::Excelx.new(file.path)
  end

  before do
    event.rfid_sessions.create!(name: 'Keynote', starts_at: base, ends_at: base + 1.hour, mandatory: true)
    stayed = guest('Stayed Long')
    short = guest('Left Early')
    linked = guest('Sticker But No Read')
    guest('No Sticker')
    [stayed, short, linked].each_with_index { |ticket, index| bind(ticket, "00000000000000A#{index}") }
    scan('00000000000000A0', 'entry', base)
    scan('00000000000000A0', 'exit', base + 55.minutes)
    scan('00000000000000A1', 'entry', base)
    scan('00000000000000A1', 'exit', base + 20.minutes)
  end

  it 'builds every sheet a client needs, summary first' do
    expect(workbook.sheets).to eq(%w[Summary Keynote E-Certificate] + ['No Gate Read', 'Guest Visits', 'Traffic'])
  end

  it 'labels who attended a session and who did not stay long enough' do
    rows = workbook.sheet('Keynote').parse.map { |row| row.compact.map(&:to_s) }
    expect(rows.find { |row| row.include?('Stayed Long') }).to include('Attended')
    expect(rows.find { |row| row.include?('Left Early') }).to include('Not enough time')
    expect(rows.find { |row| row.include?('No Sticker') }).to include('Did not attend', 'Checked in at the desk, never in the hall')
  end

  it 'lists sticker-linked guests with no gate read before guests with no sticker' do
    rows = workbook.sheet('No Gate Read').parse
    names = rows.map(&:first).compact
    expect(names.index('Sticker But No Read')).to be < names.index('No Sticker')
    expect(rows.flatten.compact).to include('Sticker linked, no gate read', 'No sticker linked')
  end

  describe 'extra custom-field columns' do
    before do
      event.update!(labels_data: { 'nama_agensi' => 'Nama Agensi' })
      event.tickets.find_by!(attendee_name: 'Stayed Long')
           .update_columns(custom_fields_data: { 'nama_agensi' => 'JKR', 'kategori' => 'KERAJAAN', '_internal' => 'x' })
    end

    def workbook_with(fields)
      file = Tempfile.new(['report', '.xlsx'], binmode: true)
      file.write(described_class.new(event, now: base + 3.hours, fields: fields).call)
      file.flush
      Roo::Excelx.new(file.path)
    end

    it 'offers event labels, falls back to the key, and hides reserved keys' do
      expect(described_class.custom_fields(event)).to eq('nama_agensi' => 'Nama Agensi', 'kategori' => 'Kategori')
    end

    it 'adds the picked fields after Ticket type on every guest sheet, ignoring unknown keys' do
      book = workbook_with(%w[kategori nama_agensi _internal bogus])
      %w[Keynote Guest\ Visits No\ Gate\ Read E-Certificate].each do |name|
        rows = book.sheet(name).parse
        header = rows.find { |row| row.include?('Ticket type') }
        expect(header.compact.first(4)).to eq(['Guest', 'Ticket type', 'Kategori', 'Nama Agensi'])
      end
      row = book.sheet('Guest Visits').parse.find { |r| r.include?('Stayed Long') }
      expect(row.first(4)).to eq(['Stayed Long', 'Delegate', 'KERAJAAN', 'JKR'])
    end

    it 'leaves the workbook unchanged when nothing is picked' do
      header = workbook_with([]).sheet('Guest Visits').parse.find { |row| row.include?('Ticket type') }
      expect(header.compact.first(3)).to eq(['Guest', 'Ticket type', 'Times entered'])
    end
  end
end
