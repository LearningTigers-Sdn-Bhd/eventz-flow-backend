require 'roo'

# Parses an uploaded exhibitor import .xlsx (from ExhibitorKitImportTemplateService)
# and creates vendor accounts + ExhibitorKit bookings, row by row. A bad row is
# recorded in `errors` and does not stop the rest of the file — same contract as
# TicketExcelService / VisitorExcelService.
class ExhibitorKitImportService
  REQUIRED_HEADERS = %w[
    Vendor\ Email PIC\ Name PIC\ Contact Booth\ Type Price\ Label Booth\ Quantity Payment\ Status
  ].freeze

  # Never required — always optional, on every booth type. For a non-inventory
  # booth type it's just a free-text label. For an inventory-managed one
  # (see #resolve_inventory_booth!), a value claims that exact physical booth
  # right away; leaving it blank still books the booth type/capacity but leaves
  # the physical booth unassigned, to be picked later via the Booths page
  # (same "assign after the fact" path as any other unassigned booking).
  BOOTH_NO_HEADER = 'Booth No'

  # Raised for anything wrong with a row's Booth No against real ExhibitorBooth
  # inventory — not found, wrong booth price, or already taken. Caught by the
  # generic StandardError rescue in #import like any other row failure, except
  # BoothAlreadyTaken which gets its own rescue so the preview can flag it.
  InvalidBoothNumber = Class.new(StandardError)
  BoothAlreadyTaken = Class.new(InvalidBoothNumber)

  # Row-content dedupe fingerprint (vendor + booth price + package + quantity),
  # stamped on every kit this service creates. Re-uploading the same file — the
  # actual bug this guards against — produces identical fingerprints for every
  # row, so they land in `skipped` (not `created`, not silently re-booked)
  # unless the caller explicitly approves that row via `force_duplicate_rows`
  # (e.g. an admin deliberately wants a second, identical booking).
  FINGERPRINT_KEY = '_import_dedupe_fingerprint'

  def self.import(file, event:, current_user:, dry_run: false, force_duplicate_rows: [])
    new(event, current_user: current_user).import(file, dry_run: dry_run, force_duplicate_rows: force_duplicate_rows)
  end

  def initialize(event, current_user: nil)
    @event = event
    @current_user = current_user
  end

  def import(file, dry_run: false, force_duplicate_rows: [])
    results = { created: { count: 0, data: [] }, skipped: { count: 0, data: [] }, errors: { count: 0, data: [] } }
    force_duplicate_rows = force_duplicate_rows.map(&:to_i).to_set

    # Snapshotted once, up front — not re-queried per row. Two identical rows
    # within *this same file* (a deliberate double booking) must both be allowed
    # to create; only fingerprints that existed before this run started count as
    # "a duplicate". Re-querying live would make row 2 wrongly see row 1's
    # just-committed kit from a few lines above and skip itself.
    existing_fingerprints = existing_fingerprint_index

    # In-file dedupe for inventory Booth No, keyed by [booth_price_id, normalized
    # number] => the row that claimed it. Doubles as the *only* protection against
    # a duplicate Booth No during dry_run: the DB lock inside the per-row
    # transaction would normally catch this too, but dry_run always rolls back,
    # so row 2 would otherwise see the booth as still available.
    claimed_booth_numbers = {}

    xlsx = Roo::Spreadsheet.open(file.respond_to?(:path) ? file.path : file)
    sheet = xlsx.sheet('Exhibitors')

    header_row = (1..sheet.last_column).map { |col| sheet.cell(1, col)&.to_s&.strip }
    # Any column that isn't one of the known fixed headers is treated as a custom
    # field — no "Custom: " prefix needed, so it reads like a normal column and the
    # template can add/remove custom columns freely without a naming convention.
    custom_columns = header_row.each_index.select do |i|
      header_row[i].present? && !ExhibitorKitImportTemplateService::FIXED_HEADERS.include?(header_row[i])
    end

    (2..sheet.last_row).each do |row_num|
      row = header_row.each_index.each_with_object({}) { |i, h| h[header_row[i]] = sheet.cell(row_num, i + 1) }

      next if row.values_at(*REQUIRED_HEADERS).all?(&:blank?) # fully empty row

      begin
        import_row!(row, custom_columns, header_row, dry_run: dry_run, results: results, row_num: row_num,
          force_duplicate_rows: force_duplicate_rows, existing_fingerprints: existing_fingerprints,
          claimed_booth_numbers: claimed_booth_numbers)
      rescue ExhibitorBookingCapacity::SoldOut
        record_error(results, row_num, 'Booth price or zone quota exceeded', row: row)
      rescue BoothAlreadyTaken => e
        record_error(results, row_num, e.message, row: row, booth_taken: true)
      rescue StandardError => e
        record_error(results, row_num, e.message, row: row)
      end
    end

    results
  end

  private

  def import_row!(row, custom_columns, header_row, dry_run:, results:, row_num:, force_duplicate_rows:, existing_fingerprints:,
    claimed_booth_numbers:)
    missing = REQUIRED_HEADERS.select { |h| row[h].blank? }
    if missing.any?
      record_error(results, row_num, "Missing required field(s): #{missing.join(', ')}", row: row)
      return
    end

    booth_price = resolve_booth_price(booth_type: row['Booth Type'], zone: row['Zone'], label: row['Price Label'])
    unless booth_price
      record_error(results, row_num, 'No matching booth price for given Booth Type/Zone/Price Label', row: row)
      return
    end

    package = resolve_package(name: row['Package Name'], booth_price: booth_price)
    if row['Package Name'].present? && package.nil?
      record_error(results, row_num, "Package '#{row['Package Name']}' does not match the resolved booth price", row: row)
      return
    end

    quantity = row['Booth Quantity'].to_i
    if quantity <= 0
      record_error(results, row_num, 'Booth Quantity must be a positive integer', row: row)
      return
    end

    # Booth No is optional even for an inventory-managed booth type: leaving it
    # blank still books the booth type/capacity, just without claiming a specific
    # physical booth — the kit can be assigned one later via the Booths page
    # (ExhibitorBoothsController#assign), the same "assign after the fact" path
    # already used for bookings made without a number picked up front.
    booth_number = row[BOOTH_NO_HEADER].to_s.strip.presence
    booth_key = nil
    if booth_price.inventory? && booth_number.present?
      if quantity != 1
        record_error(results, row_num, 'Booth Quantity must be 1 when Booth No is used (inventory booths are numbered one at a time)', row: row)
        return
      end

      booth_key = [booth_price.id, booth_number.upcase]
      prior_row = claimed_booth_numbers[booth_key]
      if prior_row
        record_error(results, row_num, "Booth No '#{booth_number}' is already used by row #{prior_row} in this file", row: row)
        return
      end
    end

    payment_status = row['Payment Status'].to_s.strip.downcase
    unless ExhibitorKit.payment_statuses.key?(payment_status)
      record_error(results, row_num, "Payment Status must be one of: #{ExhibitorKit.payment_statuses.keys.join(', ')}", row: row)
      return
    end

    vendor_email = row['Vendor Email'].to_s.strip.downcase
    fingerprint = row_fingerprint(vendor_email: vendor_email, booth_price: booth_price, package: package, quantity: quantity)
    duplicate = existing_fingerprints[fingerprint]
    if duplicate && !force_duplicate_rows.include?(row_num)
      results[:skipped][:count] += 1
      results[:skipped][:data] << row_preview(
        row_num: row_num, row: row, booth_price: booth_price, package: package,
        quantity: quantity, payment_status: payment_status, booth_number: booth_number
      ).merge(
        duplicate: true,
        existing_kit_id: duplicate[:id],
        existing_kit_public_id: duplicate[:public_id],
        existing_created_at: duplicate[:created_at],
        error: "Matches an existing booking (kit ##{duplicate[:id]}, created #{duplicate[:created_at].strftime('%Y-%m-%d %H:%M')}). " \
               'Approve this row to import it anyway.'
      )
      return
    end

    custom_fields_data = custom_columns.each_with_object({}) do |i, h|
      value = row[header_row[i]]
      next if value.blank?

      key = TicketExcelService.machine_key_for(header_row[i])
      # Guard against a stray/hand-edited custom column colliding with an
      # internal bookkeeping key (dedup fingerprints, batch ids, etc.) — see
      # ExhibitorKit::SYSTEM_CUSTOM_FIELD_KEYS. The template already excludes these,
      # this is defense in depth for files not generated from the current template.
      next if ExhibitorKit::SYSTEM_CUSTOM_FIELD_KEYS.include?(key)

      h[key] = value.to_s
    end

    if dry_run
      ExhibitorKit.transaction do
        @event.lock!
        # Resolve the specific requested booth first — when it's the reason capacity
        # would fail (the only bookable booth left is a different one, or none at
        # all), that's a more useful error than the generic quota message below.
        resolve_inventory_booth!(booth_price: booth_price, booth_number: booth_number) if booth_price.inventory? && booth_number.present?
        check_capacity!(booth_price: booth_price, package: package, quantity: quantity)
        raise ActiveRecord::Rollback # dry run: validate only, never persist
      end
      claimed_booth_numbers[booth_key] = row_num if booth_key

      results[:created][:count] += 1
      results[:created][:data] << row_preview(
        row_num: row_num, row: row, booth_price: booth_price, package: package,
        quantity: quantity, payment_status: payment_status, booth_number: booth_number
      )
      return
    end

    kit = nil
    new_user = nil
    password = nil
    claimed_booth = nil

    ExhibitorKit.transaction do
      @event.lock!
      claimed_booth = resolve_inventory_booth!(booth_price: booth_price, booth_number: booth_number) if booth_price.inventory? && booth_number.present?
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
        booth_number: claimed_booth&.number || booth_number,
        booth_quantity: quantity,
        amount_paid: row['Amount Paid'],
        price_snapshot: package&.price || booth_price.current_price,
        payment_status: payment_status,
        booking_status: booking_status,
        custom_fields_data: custom_fields_data.merge(FINGERPRINT_KEY => fingerprint)
      )

      # Claim the physical booth in the same transaction as the kit — a booked
      # kit with no corresponding booth claim (or vice versa) would let the
      # normal manual-add flow sell this same booth again.
      claimed_booth&.update!(status: (booking_status == :paid ? :booked : :reserved), exhibitor_kit: kit)
    end
    claimed_booth_numbers[booth_key] = row_num if booth_key

    if new_user
      EmailDelivery::AuditedDelivery.deliver_now(
        mailer_name: 'PublicExhibitorWelcomeMailer', mailer_action: 'welcome',
        args: [new_user.email, password, new_user.full_name], related: new_user, metadata: {}, dedupe: true
      )
    end

    results[:created][:count] += 1
    results[:created][:data] << row_preview(
      row_num: row_num, row: row, booth_price: booth_price, package: package,
      quantity: quantity, payment_status: payment_status, booth_number: booth_number
    ).merge(id: kit.id, public_id: kit.public_id)
  end

  # Shared row summary for both the dry-run preview and a real created row, so the
  # frontend preview table and the post-import results table render identically
  # (real rows just additionally carry id/public_id, dry-run rows don't since
  # nothing was persisted).
  def row_preview(row_num:, row:, booth_price:, package:, quantity:, payment_status:, booth_number: nil)
    {
      row: row_num,
      vendor_email: row['Vendor Email'].to_s.strip.downcase,
      vendor_name: row['Vendor Name'],
      company_name: row['Company Name'],
      pic_name: row['PIC Name'],
      booth_type: booth_price.booth_type,
      zone: booth_price.zone,
      price_label: booth_price.label,
      booth_no: booth_number,
      package_name: package&.name,
      booth_quantity: quantity,
      payment_status: payment_status,
      amount: (package&.price || booth_price.current_price).to_f
    }
  end

  # `row` is the raw sheet row, not a resolved booth_price/package — a row can fail
  # precisely because it didn't resolve, so this reads straight from the cells the
  # admin typed, letting the preview table show what was entered even on failure.
  # `booth_taken:` flags the specific case of a Booth No that belongs to another,
  # already-booked ExhibitorBooth — distinct from "not found"/"wrong type" so the
  # frontend can badge it the same way a duplicate vendor booking is badged.
  def record_error(results, row_num, message, row: nil, booth_taken: false)
    results[:errors][:count] += 1
    entry = { row: row_num, error: message }
    entry[:booth_taken] = true if booth_taken
    entry.merge!(raw_row_summary(row)) if row
    results[:errors][:data] << entry
  end

  def raw_row_summary(row)
    {
      vendor_email: row['Vendor Email'].to_s.strip.downcase.presence,
      vendor_name: row['Vendor Name'],
      company_name: row['Company Name'],
      pic_name: row['PIC Name'],
      booth_type: row['Booth Type'],
      zone: row['Zone'],
      price_label: row['Price Label'],
      booth_no: row[BOOTH_NO_HEADER].to_s.strip.presence,
      package_name: row['Package Name'],
      booth_quantity: row['Booth Quantity'],
      payment_status: row['Payment Status']
    }
  end

  # Content-based, not identity-based: same vendor + same booth price + same
  # package + same quantity always hashes the same, regardless of which file or
  # upload it came from. That's what makes re-uploading an unchanged file inert.
  def row_fingerprint(vendor_email:, booth_price:, package:, quantity:)
    Digest::SHA256.hexdigest([vendor_email, booth_price.id, package&.id, quantity].join('|'))
  end

  # One query, snapshotted before any row in this run is processed — see the
  # comment in #import for why this can't be a live per-row lookup. Only
  # *active/paid* kits count — a cancelled/expired booking freeing up the same
  # booth/package/quantity combo should be rebookable, not flagged as a duplicate
  # of itself. Fingerprints are only ever written by this service, so a match
  # here always means "already imported in an earlier run of this exact file."
  def existing_fingerprint_index
    ExhibitorKit.joins(:event_vendor)
      .where(event_vendors: { event_id: @event.id })
      .merge(ExhibitorKit.active_or_paid)
      .where("custom_fields_data ->> ? IS NOT NULL", FINGERPRINT_KEY)
      .pluck(Arel.sql("custom_fields_data ->> '#{FINGERPRINT_KEY}'"), :id, :public_id, :created_at)
      .each_with_object({}) do |(fingerprint, id, public_id, created_at), index|
        index[fingerprint] ||= { id: id, public_id: public_id, created_at: created_at }
      end
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

  # Locks and validates a real ExhibitorBooth for an inventory-managed booth
  # price — same rule set EventVendorBatchService#lock_inventory! applies for the
  # manual "add exhibitor" flow, so an imported row can't create a kit while
  # leaving the actual booth inventory unaware it was just sold. Must run inside
  # the row's transaction (uses .lock) — both the dry_run and real create paths
  # call this there.
  def resolve_inventory_booth!(booth_price:, booth_number:)
    booth = @event.exhibitor_booths.lock.find_by(number: booth_number.to_s.strip.upcase)
    raise InvalidBoothNumber, "Booth No '#{booth_number}' was not found for this event" unless booth
    unless booth.exhibitor_booth_price_id == booth_price.id
      raise InvalidBoothNumber, "Booth No '#{booth_number}' does not belong to the resolved Booth Type/Zone/Price Label"
    end
    raise BoothAlreadyTaken, "Booth No '#{booth_number}' is already taken" unless booth.available? && booth.bookable?

    booth
  end
end
