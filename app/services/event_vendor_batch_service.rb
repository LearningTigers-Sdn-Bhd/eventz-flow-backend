class EventVendorBatchService
  PackageMismatch = Class.new(StandardError)
  InvalidBooths = Class.new(StandardError)
  InvalidInventoryBooth = Class.new(StandardError)
  IdempotencyConflict = Class.new(StandardError)

  BATCH_KEY_FIELD = 'admin_batch_key'.freeze
  FINGERPRINT_FIELD = 'admin_batch_fingerprint'.freeze

  Result = Data.define(:success, :data, :errors, :idempotent_replay) do
    def success? = success
    def failure? = !success
    def idempotent_replay? = idempotent_replay
  end

  def self.create(event:, params:, current_user:, idempotency_key:)
    new(event:, params:, current_user:, idempotency_key:).call
  end

  def initialize(event:, params:, current_user:, idempotency_key:)
    @event = event
    @params = normalize(params)
    @current_user = current_user
    @idempotency_key = normalize(idempotency_key)
    @fingerprint = Digest::SHA256.hexdigest(JSON.generate(canonicalize(@params)))
  end

  def call
    return failure('Idempotency key is required') if @idempotency_key.blank?

    vendor = User.find_by(id: value_for(@params, :vendor_id), role: :vendor)
    return failure('Vendor not found') unless vendor

    exhibitor = @event.exhibitors.build(
      vendor: vendor,
      redirect_url: value_for(@params, :redirect_url),
      poster_url: value_for(@params, :poster_url),
      qr_url: value_for(@params, :qr_url)
    )
    authorize!(exhibitor)

    existing = existing_batch(vendor)
    return replay(existing) if existing && batch_fingerprint(existing) == @fingerprint
    return failure(IdempotencyConflict.new('Idempotency key conflicts with a different batch').message) if existing

    EventVendor.transaction do
      @event.lock!
      existing = existing_batch(vendor)
      return replay(existing) if existing && batch_fingerprint(existing) == @fingerprint
      raise IdempotencyConflict, 'Idempotency key conflicts with a different batch' if existing
      raise ActiveRecord::RecordNotUnique if @event.event_vendors.exists?(vendor: vendor)

      rows = build_rows
      lock_capacity!(rows)
      lock_inventory!(rows)

      exhibitor.save!
      vouchers = {}
      rows.each do |row|
        kit = exhibitor.exhibitor_kits.create!(kit_attributes(row))
        row[:booth]&.update!(status: :reserved, exhibitor_kit: kit)
        vouchers[row[:voucher_code]] ||= { voucher: row[:voucher], exhibitor_kit: kit } if row[:voucher]
      end
      vouchers.each_value do |redemption|
        ExhibitorVoucherRedemption.redeem!(**redemption)
      end
    end

    Result.new(success: true, data: exhibitor.reload, errors: nil, idempotent_replay: false)
  rescue PackageMismatch, InvalidBooths, InvalidInventoryBooth, IdempotencyConflict,
         ExhibitorBookingCapacity::SoldOut, ExhibitorVoucherRedemption::InvalidVoucher,
         ExhibitorVoucherRedemption::VoucherMismatch, ActiveRecord::RecordNotFound => e
    failure(e.message)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  rescue ActiveRecord::RecordNotUnique
    failure('Vendor is already assigned to this event')
  rescue Pundit::NotAuthorizedError => e
    failure(e.message)
  end

  private

  def authorize!(exhibitor)
    return if EventVendorPolicy.new(@current_user, exhibitor).create?

    raise Pundit::NotAuthorizedError, 'not allowed to create this exhibitor'
  end

  def build_rows
    raise InvalidBooths, 'At least one booth is required' if booths.empty?

    rows = booths.each_with_index.map do |booth, index|
      booth_price_id = value_for(booth, :exhibitor_booth_price_id)
      package_id = value_for(booth, :exhibitor_package_id)
      if booth_price_id.blank?
        raise PackageMismatch, 'An exhibitor package requires a booth price' if package_id.present?

        next {
          index: index,
          booth_type: value_for(booth, :booth_type),
          booth_number: value_for(booth, :booth_number),
          booth_price: nil,
          package: nil,
          amount_paid: nil,
          voucher: nil,
          voucher_code: nil
        }
      end

      booth_price = @event.exhibitor_booth_prices.find(booth_price_id)
      package = selected_package!(booth_price, package_id)
      base_price = package&.price || booth_price.current_price
      voucher_code = value_for(booth, :voucher_code)
      voucher_preview = ExhibitorVoucherRedemption.preview(
        event: @event,
        code: voucher_code,
        booth_price: booth_price,
        package: package,
        base_price: base_price
      )

      {
        index: index,
        booth_type: booth_price.booth_type,
        booth_number: value_for(booth, :booth_number),
        booth_price: booth_price,
        package: package,
        amount_paid: voucher_preview[:price],
        voucher: voucher_preview[:voucher],
        voucher_code: voucher_code
      }
    end

    reject_duplicate_inventory_booths!(rows)
    rows
  end

  def reject_duplicate_inventory_booths!(rows)
    selected_booths = {}

    rows.select { |row| row[:booth_price]&.inventory? && row[:booth_number].present? }.each do |row|
      selection = [row[:booth_price].id, row[:booth_number]]
      raise InvalidInventoryBooth, 'An inventory booth can only be selected once' if selected_booths[selection]

      selected_booths[selection] = true
    end
  end

  def lock_capacity!(rows)
    priced_rows = rows.select { |row| row[:booth_price] }
    priced_rows.group_by { |row| row[:booth_price] }.sort_by { |price, _| price.id }.each do |price, price_rows|
      ExhibitorBookingCapacity.lock!(price, quantity: price_rows.size)
    end

    priced_rows.filter_map { |row| row[:package] }.group_by(&:id).sort_by(&:first).each do |_package_id, packages|
      ExhibitorBookingCapacity.lock_package!(packages.first, quantity: packages.size)
    end
  end

  def lock_inventory!(rows)
    rows.select { |row| row[:booth_price]&.inventory? }
        .sort_by { |row| [row[:booth_price].id, row[:booth_number].to_s] }
        .each do |row|
      raise InvalidInventoryBooth, 'An inventory booth number is required' if row[:booth_number].blank?

      booth = @event.exhibitor_booths.lock.find_by(number: row[:booth_number])
      raise InvalidInventoryBooth, 'Selected inventory booth was not found' unless booth
      raise InvalidInventoryBooth, 'Selected inventory booth does not match the booth price' unless booth.exhibitor_booth_price_id == row[:booth_price].id
      raise InvalidInventoryBooth, 'Selected inventory booth is unavailable' unless booth.available? && booth.bookable?

      row[:booth] = booth
    end
  end

  def kit_attributes(row)
    {
      **exhibitor_details,
      booth_type: row[:booth_type],
      booth_number: row[:booth_number],
      booth_quantity: 1,
      exhibitor_booth_price: row[:booth_price],
      exhibitor_package: row[:package],
      amount_paid: row[:amount_paid],
      price_snapshot: row[:amount_paid] || 0,
      booking_status: :active,
      payment_status: :unpaid,
      currency: 'MYR',
      idempotency_key: "#{@idempotency_key}:#{row[:index]}",
      custom_fields_data: {
        'booking_batch_id' => booking_batch_id,
        BATCH_KEY_FIELD => @idempotency_key,
        FINGERPRINT_FIELD => @fingerprint
      }
    }
  end

  def selected_package!(booth_price, package_id)
    return nil if package_id.blank?

    package = @event.exhibitor_packages.find(package_id)
    raise PackageMismatch, 'Selected package does not match the booth price' unless package.matches_booth_price?(booth_price.id)

    package
  end

  def existing_batch(vendor)
    ExhibitorKit.joins(:event_vendor)
      .includes(:event_vendor)
      .where(event_vendors: { event_id: @event.id, vendor_id: vendor.id })
      .find { |kit| kit.custom_fields_data.to_h[BATCH_KEY_FIELD] == @idempotency_key }
  end

  def batch_fingerprint(kit)
    kit.custom_fields_data.to_h[FINGERPRINT_FIELD]
  end

  def replay(kit)
    Result.new(success: true, data: kit.event_vendor, errors: nil, idempotent_replay: true)
  end

  def booking_batch_id
    @booking_batch_id ||= SecureRandom.uuid
  end

  def booths
    value_for(@params, :booths) || []
  end

  def exhibitor_details
    details = value_for(@params, :exhibitor) || {}

    {
      company_name: value_for(details, :company_name),
      name_on_fascia: value_for(details, :name_on_fascia),
      pic_full_name: value_for(details, :pic_full_name),
      pic_contact_number: value_for(details, :pic_contact_number),
      pic_email_address: value_for(details, :pic_email_address),
      special_requirements: value_for(details, :special_requirements)
    }
  end

  def normalize(value)
    case value
    when ActionController::Parameters then normalize(value.to_h)
    when Hash then value.to_h.transform_keys(&:to_s).transform_values { |item| normalize(item) }
    when Array then value.map { |item| normalize(item) }
    when String then value.strip
    else value
    end
  end

  def canonicalize(value)
    case value
    when Hash then value.keys.sort.to_h { |key| [key, canonicalize(value[key])] }
    when Array then value.map { |item| canonicalize(item) }
    else value
    end
  end

  def value_for(payload, key)
    payload[key.to_s] || payload[key]
  end

  def failure(errors)
    Result.new(success: false, data: nil, errors: errors, idempotent_replay: false)
  end
end
