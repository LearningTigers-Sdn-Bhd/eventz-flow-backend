require 'roo'

# Parses an uploaded exhibitor import .xlsx (from ExhibitorKitImportTemplateService)
# and creates vendor accounts + ExhibitorKit bookings, row by row. A bad row is
# recorded in `errors` and does not stop the rest of the file — same contract as
# TicketExcelService / VisitorExcelService.
class ExhibitorKitImportService
  REQUIRED_HEADERS = %w[
    Vendor\ Email PIC\ Name PIC\ Contact Booth\ Type Price\ Label Booth\ Quantity Payment\ Status
  ].freeze
  CUSTOM_PREFIX = 'Custom: '

  def self.import(file, event:, current_user:, dry_run: false)
    new(event, current_user: current_user).import(file, dry_run: dry_run)
  end

  def initialize(event, current_user: nil)
    @event = event
    @current_user = current_user
  end

  def import(file, dry_run: false)
    results = { created: { count: 0, data: [] }, skipped: { count: 0, data: [] }, errors: { count: 0, data: [] } }

    xlsx = Roo::Spreadsheet.open(file.respond_to?(:path) ? file.path : file)
    sheet = xlsx.sheet('Exhibitors')

    header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col)&.to_s&.strip }
    custom_columns = header_row.each_index.select { |i| header_row[i]&.start_with?(CUSTOM_PREFIX) }

    (2..sheet.last_row).each do |row_num|
      row = header_row.each_index.each_with_object({}) { |i, h| h[header_row[i]] = sheet.cell(row_num, i + 1) }

      next if row.values_at(*REQUIRED_HEADERS).all?(&:blank?) # fully empty row

      begin
        import_row!(row, custom_columns, header_row, dry_run: dry_run, results: results, row_num: row_num)
      rescue ExhibitorBookingCapacity::SoldOut
        record_error(results, row_num, 'Booth price or zone quota exceeded')
      rescue StandardError => e
        record_error(results, row_num, e.message)
      end
    end

    results
  end

  private

  def import_row!(row, custom_columns, header_row, dry_run:, results:, row_num:)
    missing = REQUIRED_HEADERS.select { |h| row[h].blank? }
    if missing.any?
      record_error(results, row_num, "Missing required field(s): #{missing.join(', ')}")
      return
    end

    booth_price = resolve_booth_price(booth_type: row['Booth Type'], zone: row['Zone'], label: row['Price Label'])
    unless booth_price
      record_error(results, row_num, 'No matching booth price for given Booth Type/Zone/Price Label')
      return
    end

    package = resolve_package(name: row['Package Name'], booth_price: booth_price)
    if row['Package Name'].present? && package.nil?
      record_error(results, row_num, "Package '#{row['Package Name']}' does not match the resolved booth price")
      return
    end

    quantity = row['Booth Quantity'].to_i
    if quantity <= 0
      record_error(results, row_num, 'Booth Quantity must be a positive integer')
      return
    end

    payment_status = row['Payment Status'].to_s.strip.downcase
    unless ExhibitorKit.payment_statuses.key?(payment_status)
      record_error(results, row_num, "Payment Status must be one of: #{ExhibitorKit.payment_statuses.keys.join(', ')}")
      return
    end

    custom_fields_data = custom_columns.each_with_object({}) do |i, h|
      value = row[header_row[i]]
      next if value.blank?

      key = TicketExcelService.machine_key_for(header_row[i].delete_prefix(CUSTOM_PREFIX))
      # Guard against a stray/hand-edited "Custom: ..." column colliding with an
      # internal bookkeeping key (dedup fingerprints, batch ids, etc.) — see
      # ExhibitorKit::SYSTEM_CUSTOM_FIELD_KEYS. The template already excludes these,
      # this is defense in depth for files not generated from the current template.
      next if ExhibitorKit::SYSTEM_CUSTOM_FIELD_KEYS.include?(key)

      h[key] = value.to_s
    end

    if dry_run
      ExhibitorKit.transaction do
        @event.lock!
        check_capacity!(booth_price: booth_price, package: package, quantity: quantity)
      end
      return
    end

    kit = nil
    new_user = nil
    password = nil

    ExhibitorKit.transaction do
      @event.lock!
      check_capacity!(booth_price: booth_price, package: package, quantity: quantity)

      email = row['Vendor Email'].to_s.strip.downcase
      user = User.find_by('LOWER(email) = ?', email)
      if user.nil?
        password = "Sabah-#{SecureRandom.hex(4).upcase}!"
        user = User.create!(
          email: email, full_name: row['Vendor Name'], phone: row['Vendor Phone'],
          role: :vendor, password: password, password_confirmation: password,
          email_verified_at: Time.current
        )
        new_user = user
      end

      exhibitor = @event.exhibitors.find_or_create_by!(vendor: user)
      booking_status = %w[paid waived sponsored].include?(payment_status) ? :paid : :active

      kit = exhibitor.exhibitor_kits.create!(
        exhibitor_booth_price: booth_price,
        exhibitor_package: package,
        booth_type: booth_price.booth_type,
        company_name: row['Company Name'],
        company_address: row['Company Address'],
        pic_full_name: row['PIC Name'],
        pic_contact_number: row['PIC Contact'],
        pic_email_address: row['PIC Email'],
        booth_quantity: quantity,
        amount_paid: row['Amount Paid'],
        price_snapshot: package&.price || booth_price.current_price,
        payment_status: payment_status,
        booking_status: booking_status,
        custom_fields_data: custom_fields_data
      )
    end

    if new_user
      EmailDelivery::AuditedDelivery.deliver_now(
        mailer_name: 'PublicExhibitorWelcomeMailer', mailer_action: 'welcome',
        args: [new_user.email, password, new_user.full_name], related: new_user, metadata: {}, dedupe: true
      )
    end

    results[:created][:count] += 1
    results[:created][:data] << { row: row_num, id: kit.id, public_id: kit.public_id, vendor_email: kit.event_vendor.vendor.email }
  end

  def record_error(results, row_num, message)
    results[:errors][:count] += 1
    results[:errors][:data] << { row: row_num, error: message }
  end

  def resolve_booth_price(booth_type:, zone:, label:)
    scope = @event.exhibitor_booth_prices.left_joins(:exhibitor_zone).where(booth_type: booth_type, label: label)
    scope = if zone.present?
      scope.where(exhibitor_zones: { zone: zone })
    else
      scope.where(exhibitor_zone_id: nil)
    end
    scope.first
  end

  def resolve_package(name:, booth_price:)
    return nil if name.blank?

    package = booth_price.exhibitor_packages.find_by(name: name)
    return nil unless package&.matches_booth_price?(booth_price.id)

    package
  end

  def check_capacity!(booth_price:, package:, quantity:)
    ExhibitorBookingCapacity.lock!(booth_price, quantity: quantity)
    ExhibitorBookingCapacity.lock_package!(package, quantity: quantity) if package
  end
end
