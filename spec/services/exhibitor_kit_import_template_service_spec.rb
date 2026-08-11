require 'rails_helper'
require 'roo'

RSpec.describe ExhibitorKitImportTemplateService do
  let(:event) { create(:event, use_exhibitor_kit: true) }

  describe '.export' do
    it 'writes the fixed header columns on the main sheet' do
      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Exhibitors')

      header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col) }

      expect(header_row[0..14]).to eq([
        'Vendor Email', 'Vendor Name', 'Vendor Phone',
        'Company Name', 'Company Address',
        'PIC Name', 'PIC Contact', 'PIC Email',
        'Booth Type', 'Zone', 'Price Label', 'Package Name',
        'Booth Quantity', 'Amount Paid', 'Payment Status'
      ])
    end
  end

  describe '.export custom columns' do
    it 'adds one plain-named column per distinct custom_fields_data key on the event' do
      exhibitor = create(:exhibitor, event: event)
      create(:exhibitor_kit, event_vendor: exhibitor, custom_fields_data: { 't_shirt_size' => 'L' })

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Exhibitors')
      header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col) }

      expect(header_row).to include('T Shirt Size')
    end

    it 'excludes internal bookkeeping keys stored in custom_fields_data' do
      exhibitor = create(:exhibitor, event: event)
      create(:exhibitor_kit, event_vendor: exhibitor, custom_fields_data: {
        't_shirt_size' => 'L',
        'booking_batch_id' => 'abc-123',
        'payment_option' => 'now',
        'zone' => 'Hall A',
        PublicExhibitorBookingService::FINGERPRINT_KEY => 'deadbeef',
        EventVendorBatchService::FINGERPRINT_FIELD => 'deadbeef',
        EventVendorBatchService::BATCH_KEY_FIELD => 'batch-key'
      })

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Exhibitors')
      header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col) }

      expect(header_row).to include('T Shirt Size')
      # None of the excluded custom_fields_data keys should add an extra column at
      # all — 'Zone' stays present exactly once, as the fixed column, not duplicated
      # by a system-key-derived custom column.
      expect(header_row.count('Zone')).to eq(1)
      expect(header_row.grep(/Booking Batch|Payment Option|Fingerprint|Batch Key/)).to be_empty
    end
  end

  describe '.export reference sheet' do
    it 'lists current booth prices, zones, per-price and per-zone remaining quota, and packages' do
      zone = create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10)
      price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500, quota: 5)
      create(:exhibitor_package, event: event, exhibitor_booth_price: price, name: 'Basic Package', price: 600)

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Reference')

      row = (1..sheet.last_column).map { |col| sheet.cell(2, col) }
      expect(row).to eq(['Standard', 'Hall A', 'Standard 3x3', 500.0, 5, 10, 'Basic Package'])
    end

    it 'shows a full zone even when the booth price itself has unlimited quota' do
      # Reproduces the confusing case: booth price quota is nil (Unlimited) but its
      # zone quota is fully booked by existing kits — the price-level column alone
      # would wrongly suggest the row is bookable.
      zone = create(:exhibitor_zone, event: event, zone: 'Home Decor & Living', quota: 1)
      price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'shell_scheme', label: 'Prime Booth', price: 4000, quota: nil)
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: price, booth_quantity: 1, booking_status: :paid)

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Reference')

      row = (1..sheet.last_column).map { |col| sheet.cell(2, col) }
      expect(row[4]).to eq('Unlimited') # Remaining Quota (This Price)
      expect(row[5]).to eq(0)           # Remaining Quota (Zone) - actually full
    end
  end
end
