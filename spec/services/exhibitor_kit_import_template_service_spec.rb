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

      expect(header_row[0..15]).to eq([
        'Vendor Email', 'Vendor Name', 'Vendor Phone',
        'Company Name', 'Company Address',
        'PIC Name', 'PIC Contact', 'PIC Email',
        'Booth Type', 'Zone', 'Price Label', 'Booth No', 'Package Name',
        'Booth Quantity', 'Amount Paid', 'Payment Status'
      ])
    end
  end

  describe '.export custom columns' do
    it 'adds one column per label configured in the event exhibitor_labels_data schema' do
      event.update!(exhibitor_labels_data: { 't_shirt_size' => 'T Shirt Size' })

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Exhibitors')
      header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col) }

      expect(header_row).to include('T Shirt Size')
    end

    it 'adds no custom columns for a fresh event with no exhibitor_labels_data configured, even with existing kits' do
      exhibitor = create(:exhibitor, event: event)
      create(:exhibitor_kit, event_vendor: exhibitor, custom_fields_data: { 't_shirt_size' => 'L' })

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Exhibitors')
      header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col) }

      expect(header_row).not_to include('T Shirt Size')
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

      row = (1..7).map { |col| sheet.cell(2, col) }
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

    it 'appends deduped Booth Type / Zone / Price Label / Package Name lookup columns below the price table' do
      zone_a = create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10)
      price_a = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone_a,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500)
      create(:exhibitor_booth_price, event: event, exhibitor_zone: zone_a,
        booth_type: 'Standard', label: 'Standard 6x3', price: 900)
      create(:exhibitor_package, event: event, exhibitor_booth_price: price_a, name: 'Basic Package', price: 600)

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Reference')

      # price table: header (row 1) + 2 price rows (rows 2-3) -> spacer row 4,
      # lookup header row 5, first lookup value row 6. All in column A onward now.
      expect(sheet.cell(5, 1)).to eq('Booth Type (lookup)')
      expect(sheet.cell(6, 1)).to eq('Standard')
      expect(sheet.cell(6, 2)).to eq('Hall A')
      expect(sheet.cell(6, 3)).to eq('Standard 3x3')
      expect(sheet.cell(7, 3)).to eq('Standard 6x3')
      expect(sheet.cell(6, 4)).to eq('Basic Package')
    end

    it 'appends a real, valid sample row below the lookup lists (all in column A), safe from ever being imported' do
      zone = create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10)
      price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500)
      create(:exhibitor_package, event: event, exhibitor_booth_price: price, name: 'Basic Package', price: 600)

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Reference')

      header_row_num = (1..sheet.last_row).find { |r| sheet.cell(r, 1) == 'Vendor Email' }
      expect(header_row_num).to be_present

      value_row = (1..sheet.last_column).map { |c| sheet.cell(header_row_num + 1, c) }
      expect(value_row[0]).to eq('vendor@example.com') # Vendor Email
      expect(value_row[8]).to eq('Standard')             # Booth Type
      expect(value_row[10]).to eq('Standard 3x3')        # Price Label
      expect(value_row[12]).to eq('Basic Package')       # Package Name
      expect(value_row[13]).to eq(1)                     # Booth Quantity — valid, unlike the old Exhibitors-sheet attempt
    end

    it 'is on the Reference sheet, so ExhibitorKitImportService (which only reads the Exhibitors sheet) never sees it' do
      create(:exhibitor_booth_price, event: event, booth_type: 'Standard', label: 'Standard 3x3', price: 500)

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      exhibitors_sheet = xlsx.sheet('Exhibitors')

      expect((1..exhibitors_sheet.last_row).map { |r| exhibitors_sheet.cell(r, 1) }).not_to include('vendor@example.com')
    end

    it 'lists only bookable ExhibitorBooth numbers, grouped by Booth Type/Zone/Price Label, in the Available Booth Numbers table' do
      zone = create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10)
      price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'A-02')
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'A-01')
      taken = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'A-03', status: :booked)
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event), exhibitor_booth_price: price,
        booth_quantity: 1, booking_status: :paid).tap { |kit| taken.update!(exhibitor_kit: kit) }

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Reference')

      title_row = (1..sheet.last_row).find { |r| sheet.cell(r, 1).to_s.include?('Available Booth Numbers') }
      expect(title_row).to be_present
      expect(sheet.cell(title_row + 1, 1)).to eq('Booth Type')
      expect(sheet.cell(title_row + 1, 4)).to eq('Booth No')
      expect(sheet.cell(title_row + 2, 4)).to eq('A-01') # sorted, and A-03 (taken) excluded
      expect(sheet.cell(title_row + 3, 4)).to eq('A-02')
      expect(sheet.cell(title_row + 4, 4)).to be_nil # A-03 never appears — it's booked
    end

    it 'skips the Available Booth Numbers table entirely for an event with no ExhibitorBooth inventory' do
      create(:exhibitor_booth_price, event: event, booth_type: 'Standard', label: 'Standard 3x3', price: 500)

      result = described_class.export(event.id)
      xlsx = Roo::Spreadsheet.open(result[:file_path])
      sheet = xlsx.sheet('Reference')

      titles = (1..sheet.last_row).map { |r| sheet.cell(r, 1) }
      expect(titles).not_to include(a_string_matching(/Available Booth Numbers/))
    end
  end

  describe '.export dropdown validation' do
    it 'restricts Booth Type/Zone/Price Label/Package Name columns to the Reference sheet lookup range' do
      zone = create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10)
      create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500)

      result = described_class.export(event.id)
      sheet_xml = read_zip_entry(result[:file_path], 'xl/worksheets/sheet1.xml')
      doc = Nokogiri::XML(sheet_xml)
      validations = doc.css('dataValidation').to_h { |node| [node['sqref'], node.at_css('formula1')&.text] }

      # 1 price row (no package) -> spacer row 3, lookup header row 4, values start row 5.
      # Lookup lists live in column A onward on the Reference sheet now (stacked, not beside the price table).
      expect(validations['I2:I500']).to eq('Reference!$A$5:$A$5')
      expect(validations['J2:J500']).to eq('Reference!$B$5:$B$5')
      expect(validations['K2:K500']).to eq('Reference!$C$5:$C$5')
      expect(validations['M2:M500']).to be_nil # no package configured -> nothing to restrict to (L = Booth No, no dropdown)
    end

    it 'adds a header comment pointing to the Reference sheet for each restricted column' do
      result = described_class.export(event.id)
      comments_xml = read_zip_entry(result[:file_path], 'xl/comments1.xml')
      doc = Nokogiri::XML(comments_xml)
      refs = doc.css('comment').map { |node| node['ref'] }

      expect(refs).to include('I1', 'J1', 'K1', 'M1')
    end

    it 'restricts Booth No to the bookable-booths lookup range when the event has inventory booths' do
      zone = create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10)
      price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'A-01')

      result = described_class.export(event.id)
      sheet_xml = read_zip_entry(result[:file_path], 'xl/worksheets/sheet1.xml')
      doc = Nokogiri::XML(sheet_xml)
      validations = doc.css('dataValidation').to_h { |node| [node['sqref'], node.at_css('formula1')&.text] }

      expect(validations['L2:L500']).to eq('Reference!$E$5:$E$5')
    end

    it 'has no Booth No dropdown when the event has no inventory booths' do
      create(:exhibitor_booth_price, event: event, booth_type: 'Standard', label: 'Standard 3x3', price: 500)

      result = described_class.export(event.id)
      sheet_xml = read_zip_entry(result[:file_path], 'xl/worksheets/sheet1.xml')
      doc = Nokogiri::XML(sheet_xml)
      validations = doc.css('dataValidation').to_h { |node| [node['sqref'], node.at_css('formula1')&.text] }

      expect(validations['L2:L500']).to be_nil
    end

    it 'restricts Payment Status to the fixed enum via an inline list' do
      result = described_class.export(event.id)
      sheet_xml = read_zip_entry(result[:file_path], 'xl/worksheets/sheet1.xml')
      doc = Nokogiri::XML(sheet_xml)
      validation = doc.css('dataValidation').find { |node| node['sqref'] == 'P2:P500' }

      expect(validation.at_css('formula1').text).to eq('"unpaid,paid,waived,sponsored,deposit"')
    end

    it 'adds a required-field comment for non-reference required columns (e.g. Vendor Email)' do
      result = described_class.export(event.id)
      comments_xml = read_zip_entry(result[:file_path], 'xl/comments1.xml')
      doc = Nokogiri::XML(comments_xml)
      refs = doc.css('comment').map { |node| node['ref'] }

      # A1 = Vendor Email
      expect(refs).to include('A1')
    end
  end
end

def read_zip_entry(file_path, entry_name)
  Zip::File.open(file_path) { |zip| zip.read(entry_name) }
end
