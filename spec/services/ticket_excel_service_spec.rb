require 'rails_helper'
require 'roo'

RSpec.describe TicketExcelService do
  let(:event) { create(:event) }
  let(:general) { create(:ticket_type, event: event, name: 'General Admission') }
  let(:vip) { create(:ticket_type, event: event, name: 'VIP') }

  def sheet_names(file_path)
    Roo::Spreadsheet.open(file_path).sheets
  end

  describe '.export' do
    it 'keeps the flat "Tickets" sheet as sheet 0 with the original reimportable column layout' do
      create(:ticket, :checked_in, event: event, ticket_type: general, attendee_name: 'Siti')

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])

      expect(xlsx.sheets.first).to eq('Tickets')
      header = xlsx.sheet('Tickets').row(1)
      expect(header).to eq(TicketExcelService::FLAT_HEADERS)
      expect(xlsx.sheet('Tickets').row(2)[0]).to eq('Siti')
    end

    it 'adds one detail tab per ticket type present, plus a Summary sheet' do
      create(:ticket, event: event, ticket_type: general)
      create(:ticket, event: event, ticket_type: vip)

      result = described_class.export(event.id)

      expect(sheet_names(result[:file_path])).to include('General Admission', 'VIP', 'Summary')
    end

    it 'adds a Group List sheet only when the event has ticket groups' do
      create(:ticket, event: event, ticket_type: general, attendee_name: 'Siti')
      expect(sheet_names(described_class.export(event.id)[:file_path])).not_to include('Group List')

      event.update!(use_ticket_groups: true)
      room = event.ticket_groups.create!(name: 'Room A', position: 1)
      create(:ticket, event: event, ticket_type: vip, attendee_name: 'Ali', ticket_group: room)

      xlsx = Roo::Spreadsheet.open(described_class.export(event.id)[:file_path])
      rows = xlsx.sheet('Group List').parse(headers: true).map { |r| r.values_at('Group', 'Attendee Name') }
      expect(rows).to eq([['Group', 'Attendee Name'], ['Room A', 'Ali'], ['No group', 'Siti']])
      expect(xlsx.sheet('Tickets').row(1)).to eq(TicketExcelService::FLAT_HEADERS)
    end

    it 'scopes to a single ticket type when ticket_type_id is given' do
      create(:ticket, event: event, ticket_type: general)
      create(:ticket, event: event, ticket_type: vip)

      result = described_class.export(event.id, ticket_type_id: vip.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])

      expect(xlsx.sheet('Tickets').last_row).to eq(2) # header + 1 VIP ticket
      expect(sheet_names(result[:file_path])).not_to include('General Admission')
    end

    it 'only adds an Entry Timeline sheet when the event allows multiple scans' do
      single_scan_event = create(:event, multiple_scans: false)
      single_scan_type = create(:ticket_type, event: single_scan_event, name: 'General Admission')
      create(:ticket, event: single_scan_event, ticket_type: single_scan_type)

      without_rescans = described_class.export(single_scan_event.id)
      expect(sheet_names(without_rescans[:file_path])).not_to include('Entry Timeline')

      multi_scan_event = create(:event, multiple_scans: true, multiple_scan_mode: :unlimited)
      multi_scan_type = create(:ticket_type, event: multi_scan_event, name: 'General Admission')
      ticket = create(:ticket, event: multi_scan_event, ticket_type: multi_scan_type)
      create(:scan_log, event: multi_scan_event, scannable: ticket)

      with_rescans = described_class.export(multi_scan_event.id)
      xlsx = Roo::Spreadsheet.open(with_rescans[:file_path])
      expect(sheet_names(with_rescans[:file_path])).to include('Entry Timeline')
      expect(xlsx.sheet('Entry Timeline').row(2)[1]).to eq(ticket.attendee_name)
    end
  end

  describe 'reimport keeps server-written custom fields' do
    let(:terms) do
      { 'accepted' => true, 'method' => 'checkbox_typed_name', 'acknowledged_name' => 'Ali',
        'terms_version' => 'v1', 'accepted_at' => '2026-08-23T03:33:00Z' }
    end
    let(:stored) { { 'address' => 'KK', 'legacy' => 'x', '_terms_agreement' => terms, '_indemnity' => { 'accepted' => true } } }
    let(:labels) { { 'address' => 'Address' } }

    it 'sanitize drops unknown keys but keeps reserved ones, even with no labels' do
      expect(described_class.sanitize_custom_fields(stored, labels).keys)
        .to contain_exactly('address', '_terms_agreement', '_indemnity')
      expect(described_class.sanitize_custom_fields(stored, {}).keys)
        .to contain_exactly('_terms_agreement', '_indemnity')
    end

    it 'strip_empty leaves reserved hash values intact and stringifies labels' do
      result = described_class.strip_empty_custom_fields(stored.merge('address' => nil))

      expect(result['_terms_agreement']).to eq(terms)
      expect(result['address']).to eq('')
    end
  end
end
