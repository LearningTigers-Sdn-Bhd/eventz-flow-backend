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
        'Standard', 'Hall A', 'Standard 3x3', nil,
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
      expect(kit.custom_fields_data).to eq('t_shirt_size' => 'L')

      expect(ActionMailer::Base.deliveries.map(&:subject).join).to be_present
    end

    it 'strips internal bookkeeping keys even if a stray column matches one' do
      file = build_upload(
        [[
          'systemkeys@example.com', 'System Keys', '0123456789', 'Acme', 'Addr',
          'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', nil,
          1, 500, 'unpaid', 'L', 'sneaky-batch-id', 'later'
        ]],
        custom_headers: ['T Shirt Size', 'Booking Batch Id', 'Payment Option']
      )

      described_class.import(file.path, event: event, current_user: organizer)

      kit = ExhibitorKit.last
      expect(kit.custom_fields_data).to eq('t_shirt_size' => 'L')
    end

    it 'reuses an existing vendor User and EventVendor across two rows (multi-booth)' do
      existing_user = create(:user, email: 'repeat@example.com', role: :vendor)
      file = build_upload([
        ['repeat@example.com', 'Repeat Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid', ''],
        ['repeat@example.com', 'Repeat Vendor', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid', '']
      ])

      expect {
        described_class.import(file.path, event: event, current_user: organizer)
      }.to change(User, :count).by(0).and change(EventVendor, :count).by(1).and change(ExhibitorKit, :count).by(2)

      expect(existing_user.event_vendor_assignments.where(event: event).count).to eq(1)
    end

    it 'records a row error and continues when booth price does not match' do
      file = build_upload([
        ['bad@example.com', 'Bad', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Nonexistent', 'Nowhere', 'Nope', nil, 1, 500, 'unpaid', ''],
        ['good@example.com', 'Good', '0123456789', 'Acme', 'Addr', 'Jane', '0198765432', '',
         'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid', '']
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
        'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid', ''
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
        'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid', ''
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
        'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid', ''
      ]])

      results = described_class.import(file.path, event: event, current_user: organizer, dry_run: true)

      expect(results[:errors][:count]).to eq(1)
      expect(results[:errors][:data].first[:error]).to eq('Booth price or zone quota exceeded')
      expect(User.find_by(email: 'dryrun-overflow@example.com')).to be_nil
    end
  end
end
