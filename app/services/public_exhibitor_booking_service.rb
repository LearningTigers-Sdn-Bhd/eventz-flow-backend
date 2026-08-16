require 'digest'

class PublicExhibitorBookingService
  Result = Data.define(:kit, :idempotent_replay)
  IdempotencyConflict = Class.new(StandardError)
  SoldOut = ExhibitorBookingCapacity::SoldOut
  ImmutableBooking = Class.new(StandardError)
  StaleBooking = Class.new(StandardError)
  EmailRequiresAccess = Class.new(StandardError)
  DuplicateBoothNumber = Class.new(StandardError)
  AgreementRequired = Class.new(StandardError)
  BoothNumberRequired = Class.new(StandardError)
  BoothNotFound = Class.new(StandardError)
  BoothUnavailable = Class.new(StandardError)
  BoothPriceMismatch = Class.new(StandardError)
  PackageMismatch = Class.new(StandardError)

  FINGERPRINT_KEY = '_public_booking_fingerprint'

  def self.call(event:, access:, idempotency_key:, attributes:, new_registration: false)
    new(event:, access:).create(idempotency_key:, attributes:, new_registration: new_registration)
  end

  def self.call_batch(event:, access:, idempotency_key:, shared_attributes:, booths:, new_registration: false)
    new(event:, access:).create_batch(idempotency_key:, shared_attributes:, booths:, new_registration: new_registration)
  end

  def initialize(event:, access:)
    @event = event
    @access = access
  end

  def create(idempotency_key:, attributes:, new_registration: false)
    raise ArgumentError, 'Idempotency-Key is required' if idempotency_key.blank?

    normalized = normalize(attributes)
    raise AgreementRequired unless ActiveModel::Type::Boolean.new.cast(normalized['indemnity_signed'])
    fingerprint = Digest::SHA256.hexdigest(JSON.generate(normalized))

    result, new_user, password = ExhibitorKit.transaction do
      event.lock!
      create_one!(normalized: normalized, idempotency_key: idempotency_key, new_registration: new_registration,
        allow_reuse: false, fingerprint: fingerprint)
    end

    if new_user
      EmailDelivery::AuditedDelivery.deliver_now(
        mailer_name: 'PublicExhibitorWelcomeMailer', mailer_action: 'welcome',
        args: [new_user.email, password, new_user.full_name], related: new_user, metadata: {}, dedupe: true
      )
    end
    result
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def create_batch(idempotency_key:, shared_attributes:, booths:, new_registration: false)
    raise ArgumentError, 'Idempotency-Key is required' if idempotency_key.blank?

    normalized_shared = normalize(shared_attributes)
    normalized_booths = normalize(booths)
    raise AgreementRequired unless ActiveModel::Type::Boolean.new.cast(normalized_shared['indemnity_signed'])
    fingerprint = Digest::SHA256.hexdigest(JSON.generate(shared_attributes: normalized_shared, booths: normalized_booths))
    batch_id = SecureRandom.uuid

    results, new_user, password = ExhibitorKit.transaction do
      event.lock!
      if new_registration && User.where('LOWER(email) = ?', access.normalized_email).exists?
        raise EmailRequiresAccess
      end

      exhibitor, new_user, password = find_or_create_exhibitor!(normalized_shared)
      existing = exhibitor.exhibitor_kits.lock.where(idempotency_key: normalized_booths.each_index.map {
        |index| batch_idempotency_key(idempotency_key, index)
      })
      if existing.exists?
        kits = existing.order(:id).to_a
        unless kits.first.custom_fields_data[FINGERPRINT_KEY] == fingerprint
          raise IdempotencyConflict
        end

        next [kits.map { |kit| Result.new(kit: kit, idempotent_replay: true) }, nil, nil]
      end

      batch_vouchers = {}
      results = normalized_booths.each_with_index.map do |booth, index|
        normalized = normalized_shared.merge(booth).merge(
          'custom_fields_data' => normalized_shared.fetch('custom_fields_data', {}).merge('booking_batch_id' => batch_id)
        )
        result, _new_user, _password, voucher = create_one!(
          normalized: normalized, idempotency_key: batch_idempotency_key(idempotency_key, index),
          new_registration: false, allow_reuse: index.positive?, fingerprint: fingerprint,
          redeem_voucher: false
        )
        batch_vouchers[voucher.code] ||= voucher if voucher
        result
      rescue StandardError => e
        e.define_singleton_method(:failed_booth_number) { booth['booth_number'] }
        raise
      end
      # Each distinct voucher code used across the batch is redeemed once, not once per booth,
      # so a single code can cover every booth without a per-booth quota unit being consumed.
      batch_vouchers.each_value do |voucher|
        ExhibitorVoucherRedemption.redeem!(voucher: voucher, exhibitor_kit: results.first.kit)
      end
      [results, new_user, password]
    end

    if new_user
      EmailDelivery::AuditedDelivery.deliver_now(
        mailer_name: 'PublicExhibitorWelcomeMailer', mailer_action: 'welcome',
        args: [new_user.email, password, new_user.full_name], related: new_user, metadata: {}, dedupe: true
      )
    end
    { batch_id: results.first.kit.custom_fields_data['booking_batch_id'], results: results,
      combined_amount: results.sum { |result| result.kit.amount_paid } }
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def update(kit:, expected_lock_version:, attributes:)
    normalized = normalize(attributes)
    ExhibitorKit.transaction do
      kit.lock!
      raise ImmutableBooking unless kit.unpaid? && kit.booking_active?
      raise StaleBooking unless kit.lock_version == expected_lock_version.to_i

      changes = normalized.slice(*booking_fields)
      target_price = if normalized['exhibitor_booth_price_id'].present? &&
                        normalized['exhibitor_booth_price_id'].to_i != kit.exhibitor_booth_price_id
        event.exhibitor_booth_prices.find(normalized['exhibitor_booth_price_id'])
      end

      if target_price && !target_price.inventory?
        ExhibitorBookingCapacity.lock!(target_price, quantity: kit.booth_quantity, excluding: kit)
        price = target_price.current_price
        changes.merge!(exhibitor_booth_price: target_price, booth_type: target_price.booth_type,
          amount_paid: price * kit.booth_quantity, price_snapshot: price)
      elsif target_price
        booth = move_booth!(kit, target_price, normalized['booth_number'])
        price = target_price.current_price
        changes.merge!(exhibitor_booth_price: target_price, booth_type: target_price.booth_type,
          amount_paid: price * kit.booth_quantity, price_snapshot: price,
          booth_number: booth.number)
      elsif kit.exhibitor_booth_price&.inventory? && booth_number_changed?(kit, normalized)
        booth = move_booth!(kit, kit.exhibitor_booth_price, normalized['booth_number'])
        changes[:booth_number] = booth.number
      end

      # Absent key means "leave the package alone"; a present-but-blank key means "clear it".
      if normalized.key?('exhibitor_package_id')
        effective_price = target_price || kit.exhibitor_booth_price
        package = selected_package(normalized, effective_price)
        ExhibitorBookingCapacity.lock_package!(package, quantity: kit.booth_quantity, excluding: kit) if package
        package_price = package&.price || effective_price.current_price
        changes.merge!(exhibitor_package: package, price_snapshot: package_price,
          amount_paid: package_price * kit.booth_quantity)
      end
      kit.update!(changes)
      kit
    end
  end

  def booth_number_assigned?(booth_number)
    return false if booth_number.blank?

    if event.exhibitor_booths.exists?
      booth = event.exhibitor_booths.find_by(number: booth_number.to_s.strip.upcase)
      return booth.nil? || !booth.bookable?
    end

    normalized_number = normalize_booth_number(booth_number)
    ExhibitorKit.joins(:event_vendor)
      .where(event_vendors: { event_id: event.id }, booking_status: %i[active paid])
      .pluck(:booth_number)
      .compact
      .any? { |existing| normalize_booth_number(existing) == normalized_number }
  end

  private

  attr_reader :event, :access

  def create_one!(normalized:, idempotency_key:, new_registration:, allow_reuse:, fingerprint:, redeem_voucher: true)
    if new_registration && User.where('LOWER(email) = ?', access.normalized_email).exists?
      raise EmailRequiresAccess
    end
    exhibitor, new_user, password = find_or_create_exhibitor!(normalized)
    existing = exhibitor.exhibitor_kits.lock.find_by(idempotency_key: idempotency_key)
    if existing
      raise IdempotencyConflict unless existing.custom_fields_data[FINGERPRINT_KEY] == fingerprint

      return [Result.new(kit: existing, idempotent_replay: true), nil, nil]
    end

    source = source_booking(normalized)
    booth_price = event.exhibitor_booth_prices.find(normalized.fetch('exhibitor_booth_price_id'))
    booth = if booth_price.inventory?
      claim_booth!(booth_price, normalized['booth_number'])
    else
      reject_duplicate_booth_number!(normalized['booth_number'])
      ExhibitorBookingCapacity.lock!(booth_price, quantity: 1)
      nil
    end
    package = selected_package(normalized, booth_price)
    ExhibitorBookingCapacity.lock_package!(package, quantity: 1) if package
    base_price = package&.price || booth_price.current_price
    voucher_result = ExhibitorVoucherRedemption.preview(
      event: event,
      code: normalized['voucher_code'],
      booth_price: booth_price,
      package: package,
      base_price: base_price
    )
    price = voucher_result[:price]
    custom_fields = normalized.fetch('custom_fields_data', {}).merge(
      FINGERPRINT_KEY => fingerprint,
      'payment_option' => normalized.fetch('payment_option', 'now'),
      'zone' => booth_price.zone
    )

    kit = exhibitor.exhibitor_kits.create!(normalized.slice(*booking_fields).merge(
      exhibitor_booth_price: booth_price,
      exhibitor_package: package,
      booth_type: booth_price.booth_type,
      booth_quantity: 1,
      booth_number: booth&.number || normalized['booth_number'],
      pic_email_address: exhibitor.vendor.email,
      amount_paid: price,
      price_snapshot: price,
      currency: 'MYR',
      payment_status: :unpaid,
      booking_status: :active,
      reservation_expires_at: reservation_expiry(normalized),
      idempotency_key: idempotency_key,
      custom_fields_data: custom_fields
    ))
    if voucher_result[:voucher] && redeem_voucher
      ExhibitorVoucherRedemption.redeem!(
        voucher: voucher_result[:voucher],
        exhibitor_kit: kit
      )
    end
    booth&.update!(status: :reserved, exhibitor_kit: kit)
    ExhibitorIcCopyAttacher.new(event: event, exhibitor_kit: kit,
      signed_id: normalized['ic_copy_signed_id'], allow_reuse: allow_reuse).call
    CustomsDeclarationAttacher.new(event: event, exhibitor_kit: kit,
      signed_id: normalized['customs_declaration_signed_id'], allow_reuse: allow_reuse).call
    CustomsDutyEstimateAttacher.new(event: event, exhibitor_kit: kit,
      signed_id: normalized['customs_duty_estimate_signed_id'], allow_reuse: allow_reuse).call
    IndemnityFormAttacher.new(event: event, exhibitor_kit: kit,
      signed_id: normalized['indemnity_form_signed_id'], allow_reuse: allow_reuse).call
    kit.ic_copy.attach(source.ic_copy.blob) if normalized['ic_copy_signed_id'].blank? && source&.ic_copy&.attached?
    [Result.new(kit: kit, idempotent_replay: false), new_user, password, redeem_voucher ? nil : voucher_result[:voucher]]
  end

  def reservation_expiry(normalized)
    return nil unless normalized.fetch('payment_option', 'now') == 'later'

    event.exhibitor_reservation_ttl_hours&.hours&.from_now
  end

  def find_or_create_exhibitor!(attributes)
    email = access.normalized_email
    user = User.where('LOWER(email) = ?', email).first_or_initialize
    password = nil
    if user.new_record?
      password = "Sabah-#{SecureRandom.hex(4).upcase}!"
      user.assign_attributes(email: email, full_name: attributes['pic_full_name'].presence || email,
        phone: attributes['pic_contact_number'], role: :vendor, password: password,
        password_confirmation: password, email_verified_at: Time.current)
      user.save!
    end

    [event.exhibitors.find_or_create_by!(vendor: user), password ? user : nil, password]
  end

  def source_booking(attributes)
    return if attributes['ic_copy_signed_id'].present?
    return unless ActiveModel::Type::Boolean.new.cast(attributes['reuse_ic_copy'])

    source = PublicExhibitorBookingPolicy::Scope.new(access, ExhibitorKit)
      .resolve.find_by!(public_id: attributes.fetch('source_booking_public_id'))
    raise ExhibitorIcCopyAttacher::Error, 'Source booking has no IC copy' unless source.ic_copy.attached?

    source
  end

  def reject_duplicate_booth_number!(booth_number)
    return if booth_number.blank?

    raise DuplicateBoothNumber, "Booth number #{booth_number.strip} is already assigned" if booth_number_assigned?(booth_number)
  end

  def claim_booth!(booth_price, number)
    raise BoothNumberRequired if number.blank?

    booth = event.exhibitor_booths.lock.find_by(number: number.to_s.strip.upcase)
    raise BoothNotFound if booth.nil?
    raise BoothPriceMismatch unless booth.exhibitor_booth_price_id == booth_price.id
    raise BoothUnavailable unless booth.bookable?

    booth
  end

  def booth_number_changed?(kit, normalized)
    normalized['booth_number'].present? &&
      normalized['booth_number'].to_s.strip.upcase != kit.booth_number.to_s.strip.upcase
  end

  # Release first, then claim, so moving within the same booth price sees accurate availability.
  # A failed claim raises and rolls the release back with the surrounding transaction.
  def move_booth!(kit, booth_price, number)
    kit.exhibitor_booths.update_all(status: ExhibitorBooth.statuses[:available], exhibitor_kit_id: nil)
    booth = claim_booth!(booth_price, number)
    booth.update!(status: :reserved, exhibitor_kit: kit)
    booth
  end

  def normalize_booth_number(value)
    value.to_s.downcase.gsub(/\s+/, '')
  end

  # Scoped to the event, so a package id from another event is a 404, not a mispriced booking.
  def selected_package(normalized, booth_price)
    package_id = normalized['exhibitor_package_id']
    return nil if package_id.blank?

    package = event.exhibitor_packages.find(package_id)
    raise PackageMismatch unless package.matches_booth_price?(booth_price.id)

    package
  end

  def normalize(value)
    case value
    when ActionController::Parameters then normalize(value.to_h)
    when Hash then value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { |item| normalize(item) }
    when Array then value.map { |item| normalize(item) }
    when String then value.strip
    else value
    end
  end

  def booking_fields
    %w[company_name company_address name_on_fascia pic_full_name pic_position pic_contact_number country booth_number indemnity_signed]
  end

  def batch_idempotency_key(key, index)
    "#{key}:#{index}"
  end
end
