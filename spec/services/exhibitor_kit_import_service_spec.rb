require 'rails_helper'
require 'caxlsx'

RSpec.describe ExhibitorKitImportService do
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:zone) { create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10) }
  let!(:booth_price) do
    create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
      booth_type: 'Standard', label: 'Standard 3x3', price: 500, quota: 5)
  end

  describe '.resolve_booth_price (private, tested via send)' do
    it 'matches on booth_type + zone + label' do
      service = described_class.new(event)
      resolved = service.send(:resolve_booth_price, booth_type: 'Standard', zone: 'Hall A', label: 'Standard 3x3')
      expect(resolved).to eq(booth_price)
    end

    it 'returns nil when the combo does not exist' do
      service = described_class.new(event)
      resolved = service.send(:resolve_booth_price, booth_type: 'Standard', zone: 'Hall B', label: 'Standard 3x3')
      expect(resolved).to be_nil
    end

    it 'matches booth prices with no zone when the Zone cell is blank' do
      no_zone_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: nil,
        booth_type: 'Premium', label: 'Premium 3x3', price: 800)
      service = described_class.new(event)
      resolved = service.send(:resolve_booth_price, booth_type: 'Premium', zone: '', label: 'Premium 3x3')
      expect(resolved).to eq(no_zone_price)
    end
  end

  describe '.resolve_package (private, tested via send)' do
    it 'returns the package when its name matches and it belongs to the booth price' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, name: 'Basic Package')
      service = described_class.new(event)
      resolved = service.send(:resolve_package, name: 'Basic Package', booth_price: booth_price)
      expect(resolved).to eq(package)
    end

    it 'returns nil when the package belongs to a different booth price' do
      other_price = create(:exhibitor_booth_price, event: event, booth_type: 'Premium', label: 'Premium 3x3', price: 800)
      create(:exhibitor_package, event: event, exhibitor_booth_price: other_price, name: 'Other Package')
      service = described_class.new(event)
      resolved = service.send(:resolve_package, name: 'Other Package', booth_price: booth_price)
      expect(resolved).to be_nil
    end

    it 'selects the matching package when another booth price uses the same name' do
      other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: nil,
        booth_type: 'Premium', label: 'Premium 3x3', price: 800)
      target_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: nil,
        booth_type: 'Deluxe', label: 'Deluxe 3x3', price: 1000)
      create(:exhibitor_package, event: event, exhibitor_booth_price: other_price, name: 'Shared Package')
      matching_package = create(:exhibitor_package, event: event, exhibitor_booth_price: target_price, name: 'Shared Package')
      service = described_class.new(event)

      resolved = service.send(:resolve_package, name: 'Shared Package', booth_price: target_price)

      expect(resolved).to eq(matching_package)
    end

    it 'returns nil when name is blank' do
      service = described_class.new(event)
      resolved = service.send(:resolve_package, name: '', booth_price: booth_price)
      expect(resolved).to be_nil
    end
  end

  describe '.check_capacity! (private, tested via send)' do
    it 'does not raise when quota is available' do
      service = described_class.new(event)
      expect { service.send(:check_capacity!, booth_price: booth_price, package: nil, quantity: 1) }.not_to raise_error
    end

    it 'raises ExhibitorBookingCapacity::SoldOut when booth price quota is exceeded' do
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price, booth_quantity: 5, booking_status: :paid)
      service = described_class.new(event)
      expect {
        service.send(:check_capacity!, booth_price: booth_price, package: nil, quantity: 1)
      }.to raise_error(ExhibitorBookingCapacity::SoldOut)
    end
  end

  describe '.import' do
    let!(:organizer) { create(:user, role: :organizer) }

    def build_upload(rows, custom_headers: ['T Shirt Size'])
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
        sheet.add_row(ExhibitorKitImportTemplateService::FIXED_HEADERS + custom_headers)
        rows.each { |row| sheet.add_row(row) }
      end
      Tempfile.new(['import', '.xlsx']).tap do |f|
        f.binmode
        package.serialize(f.path)
        f.rewind
      end
    end

    it 'creates a new vendor User, EventVendor and ExhibitorKit, and emails the welcome mailer' do
      file = build_upload([[
        'newvendor@example.com', 'New Vendor', '0123456789',
        'Acme Sdn Bhd', '123 Main St',
        'Jane PIC', '0198765432', 'jane@example.com',
        'Standard', 'Hall A', 'Standard 3x3', '', nil,
        1, 500, 'paid', 'L'
      ]])

      expect {
        described_class.import(file.path, event: event, current_user: organizer)
      }.to change(User, :count).by(1).and change(ExhibitorKit, :count).by(1)

      user = User.find_by(email: 'newvendor@example.com')
      expect(user.role).to eq('vendor')

      kit = ExhibitorKit.last
      expect(kit.pic_full_name).to eq('Jane PIC')
      expect(kit.exhibitor_booth_price).to eq(booth_price)
      expect(kit.payment_status).to eq('paid')
      expect(kit.booking_status).to eq('paid')
      expect(kit.custom_fields_data).to include('t_shirt_size' => 'L')
      expect(kit.custom_fields_data[described_class::FINGERPRINT_KEY]).to be_present

      expect(ActionMailer::Base.deliveries.map(&:subject).join).to be_present
    end

    it 'strips internal bookkeeping keys even if a stray column matches one' do
      file = build_upload(
        [[
          'systemkeys@example.com', 'System Keys', '0123456789', 'Acme', 'Addr',
          'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', '', nil,
          1, 500, 'unpaid', 'L', 'sneaky-batch-id', 'later'
        ]],
        custom_headers: ['T Shirt Size', 'Booking Batch Id', 'Payment Option']
      )

      described_class.import(file.path, event: event, current_user: organizer)

      kit = ExhibitorKit.last
      expect(kit.custom_fields_data).to include('t_shirt_size' => 'L')
      expect(kit.custom_fields_data[described_class::FINGERPRINT_KEY]).to be_present
    end

    it 'reuses an existing vendor User and EventVendor across two rows (multi-booth)' do
      existing_user = create(:user, email: 'repeat@example.com', role: :vendor)
      file = build_upload([
        ['repeat@example.com', 'Repeat Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', ''],
        ['repeat@example.com', 'Repeat Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', '']
      ])

      expect {
        described_class.import(file.path, event: event, current_user: organizer)
      }.to change(User, :count).by(0).and change(EventVendor, :count).by(1).and change(ExhibitorKit, :count).by(2)

      expect(existing_user.event_vendor_assignments.where(event: event).count).to eq(1)
    end

    it 'skips a row that matches a booking already created in an earlier import run, instead of creating a duplicate' do
      row = ['repeat2@example.com', 'Repeat Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', '']

      first_result = described_class.import(build_upload([row]).path, event: event, current_user: organizer)
      expect(first_result[:created][:count]).to eq(1)

      expect {
        second_result = described_class.import(build_upload([row]).path, event: event, current_user: organizer)
        expect(second_result[:created][:count]).to eq(0)
        expect(second_result[:skipped][:count]).to eq(1)
        expect(second_result[:skipped][:data].first[:duplicate]).to eq(true)
        expect(second_result[:skipped][:data].first[:error]).to include('Matches an existing booking')
      }.not_to change(ExhibitorKit, :count)
    end

    it 'creates the row anyway when its row number is explicitly force-approved as a duplicate' do
      row = ['repeat3@example.com', 'Repeat Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', '']

      described_class.import(build_upload([row]).path, event: event, current_user: organizer)

      expect {
        result = described_class.import(build_upload([row]).path, event: event, current_user: organizer, force_duplicate_rows: [2])
        expect(result[:created][:count]).to eq(1)
        expect(result[:skipped][:count]).to eq(0)
      }.to change(ExhibitorKit, :count).by(1)
    end

    it 'records a row error and continues when booth price does not match' do
      file = build_upload([
        ['bad@example.com', 'Bad', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Nonexistent', 'Nowhere', 'Nope', '', nil, 1, 500, 'unpaid', ''],
        ['good@example.com', 'Good', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', '']
      ])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:created][:count]).to eq(1)

      # Error rows must still surface what was actually typed on that row —
      # otherwise the preview table has no way to show the admin which entry
      # failed beyond a bare row number.
      error_row = results[:errors][:data].first
      expect(error_row[:vendor_email]).to eq('bad@example.com')
      expect(error_row[:company_name]).to eq('Acme')
      expect(error_row[:booth_type]).to eq('Nonexistent')
      expect(error_row[:zone]).to eq('Nowhere')
    end

    it 'records a row error and does not persist when quota is already exceeded' do
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price, booth_quantity: 5, booking_status: :paid)
      file = build_upload([[
        'overflow@example.com', 'Overflow', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', ''
      ]])

      expect {
        results = described_class.import(file.path, event: event, current_user: organizer)
        expect(results[:errors][:count]).to eq(1)
        expect(results[:errors][:data].first[:error]).to eq('Booth price or zone quota exceeded')
      }.not_to change(ExhibitorKit, :count)
    end

    it 'dry_run: true validates without persisting, and returns a preview row' do
      file = build_upload([[
        'dryrun@example.com', 'Dry Run', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', ''
      ]])

      results = nil
      expect {
        results = described_class.import(file.path, event: event, current_user: organizer, dry_run: true)
      }.to change(User, :count).by(0).and change(ExhibitorKit, :count).by(0)

      expect(results[:created][:count]).to eq(1)
      preview = results[:created][:data].first
      expect(preview[:vendor_email]).to eq('dryrun@example.com')
      expect(preview[:booth_type]).to eq('Standard')
      expect(preview[:zone]).to eq('Hall A')
      expect(preview[:price_label]).to eq('Standard 3x3')
      expect(preview[:booth_quantity]).to eq(1)
      expect(preview[:payment_status]).to eq('unpaid')
      expect(preview).not_to have_key(:id) # nothing was persisted
    end

    it 'dry_run: true reports exhausted quota without persisting' do
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price, booth_quantity: 5, booking_status: :paid)
      file = build_upload([[
        'dryrun-overflow@example.com', 'Dry Run Overflow', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid', ''
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer, dry_run: true)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to eq('Booth price or zone quota exceeded')
      expect(User.find_by(email: 'dryrun-overflow@example.com')).to be_nil
    end
  end

  describe '.import with inventory booths (a Booth No column on a booth type that has real ExhibitorBooth records)' do
    let!(:organizer) { create(:user, role: :organizer) }
    let!(:inventory_booth) { create(:exhibitor_booth, event: event, exhibitor_booth_price: booth_price, number: 'A-01') }

    def build_upload(rows, custom_headers: [])
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
        sheet.add_row(ExhibitorKitImportTemplateService::FIXED_HEADERS + custom_headers)
        rows.each { |row| sheet.add_row(row) }
      end
      Tempfile.new(['import', '.xlsx']).tap do |f|
        f.binmode
        package.serialize(f.path)
        f.rewind
      end
    end

    it 'claims the matching ExhibitorBooth and stamps its number on the created kit' do
      file = build_upload([[
        'inv@example.com', 'Inv Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', 'a-01', nil, 1, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:created][:count]).to eq(1)
      kit = ExhibitorKit.last
      expect(kit.booth_number).to eq('A-01')
      expect(inventory_booth.reload.status).to eq('reserved')
      expect(inventory_booth.exhibitor_kit).to eq(kit)
    end

    it 'marks the booth booked instead of reserved when Payment Status settles the booking' do
      file = build_upload([[
        'invpaid@example.com', 'Inv Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 1, 500, 'paid'
      ]])

      described_class.import(file.path, event: event, current_user: organizer)

      expect(inventory_booth.reload.status).to eq('booked')
    end

    it 'creates the kit without claiming any booth when Booth No is left blank for an inventory-managed booth type' do
      file = build_upload([[
        'noboothno@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 1, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(0)
      expect(results[:created][:count]).to eq(1)
      kit = ExhibitorKit.last
      expect(kit.booth_number).to be_nil
      expect(kit.exhibitor_booth_price).to eq(booth_price)
      expect(inventory_booth.reload.status).to eq('available') # left for later manual assignment
    end

    it 'still enforces capacity by count when quantity > 1 and Booth No is left blank' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: booth_price, number: 'A-02')
      # Only 2 bookable booths exist (A-01 + A-02) — asking for 3 without picking
      # numbers should still fail the aggregate capacity check.
      file = build_upload([[
        'overcapacity@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', '', nil, 3, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to eq('Booth price or zone quota exceeded')
    end

    it 'errors the row when Booth No does not exist for the event' do
      file = build_upload([[
        'notfound@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', 'Z-99', nil, 1, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to include('not found')
    end

    it 'errors the row when Booth No belongs to a different booth price' do
      other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: nil, booth_type: 'Premium', label: 'Premium 3x3', price: 800)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: other_price, number: 'B-01')
      file = build_upload([[
        'wrongprice@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', 'B-01', nil, 1, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to include('does not belong to the resolved Booth Type')
    end

    it 'errors and flags booth_taken when Booth No is already claimed by another active kit' do
      taken_kit = create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price, booth_quantity: 1, booking_status: :active)
      inventory_booth.update!(status: :reserved, exhibitor_kit: taken_kit)

      file = build_upload([[
        'taken@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 1, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to include('already taken')
      expect(results[:errors][:data].first[:booth_taken]).to eq(true)
    end

    it 'errors the row when Booth Quantity is more than 1 alongside a Booth No' do
      file = build_upload([[
        'multiqty@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 3, 500, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to include('Booth Quantity must be 1')
    end

    it 'errors the second row when two rows in the same file claim the same Booth No' do
      file = build_upload([
        ['dup1@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 1, 500, 'unpaid'],
        ['dup2@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 1, 500, 'unpaid']
      ])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:created][:count]).to eq(1)
      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to include('already used by row 2')
    end

    it 'dry_run: true validates the booth without claiming it, and still catches an in-file duplicate' do
      file = build_upload([
        ['dry1@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 1, 500, 'unpaid'],
        ['dry2@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', 'A-01', nil, 1, 500, 'unpaid']
      ])

      results = nil
      expect {
        results = described_class.import(file.path, event: event, current_user: organizer, dry_run: true)
      }.not_to change(ExhibitorKit, :count)

      expect(results[:created][:count]).to eq(1)
      expect(results[:created][:data].first[:booth_no]).to eq('A-01')
      expect(results[:errors][:count]).to eq(1)
      expect(inventory_booth.reload.status).to eq('available') # never actually claimed
    end

    it 'passes Booth No straight through as a label for a booth type with no ExhibitorBooth inventory' do
      no_inventory_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: nil,
        booth_type: 'Premium', label: 'Premium 3x3', price: 800)
      file = build_upload([[
        'freeform@example.com', 'Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
        'Premium', '', 'Premium 3x3', 'Whatever I Want', nil, 2, 800, 'unpaid'
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer)

      expect(results[:errors][:count]).to eq(0)
      expect(ExhibitorKit.last.booth_number).to eq('Whatever I Want')
    end
  end
end
