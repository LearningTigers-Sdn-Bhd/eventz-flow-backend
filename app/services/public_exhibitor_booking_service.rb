require 'digest'

class PublicExhibitorBookingService
  Result = Data.define(:kit, :idempotent_replay)
  IdempotencyConflict = Class.new(StandardError)
  SoldOut = ExhibitorBookingCapacity::SoldOut
  ImmutableBooking = Class.new(StandardError)
  StaleBooking = Class.new(StandardError)
  EmailRequiresAccess = Class.new(StandardError)

  RESERVATION_TTL = 48.hours
  FINGERPRINT_KEY = '_public_booking_fingerprint'

  def self.call(event:, access:, idempotency_key:, attributes:, new_registration: false)
    new(event:, access:).create(idempotency_key:, attributes:, new_registration: new_registration)
  end

  def initialize(event:, access:)
    @event = event
    @access = access
  end

  def create(idempotency_key:, attributes:, new_registration: false)
    raise ArgumentError, 'Idempotency-Key is required' if idempotency_key.blank?

    normalized = normalize(attributes)
    fingerprint = Digest::SHA256.hexdigest(JSON.generate(normalized))

    result, new_user, password = ExhibitorKit.transaction do
      event.lock!
      if new_registration && User.where('LOWER(email) = ?', access.normalized_email).exists?
        raise EmailRequiresAccess
      end
      exhibitor, new_user, password = find_or_create_exhibitor!(normalized)
      existing = exhibitor.exhibitor_kits.lock.find_by(idempotency_key: idempotency_key)
      if existing
        raise IdempotencyConflict unless existing.custom_fields_data[FINGERPRINT_KEY] == fingerprint

        next [Result.new(kit: existing, idempotent_replay: true), nil, nil]
      end

      source = source_booking(normalized)
      booth_price = event.exhibitor_booth_prices.find(normalized.fetch('exhibitor_booth_price_id'))
      ExhibitorBookingCapacity.lock!(booth_price, quantity: 1)
      price = booth_price.current_price
      custom_fields = normalized.fetch('custom_fields_data', {}).merge(
        FINGERPRINT_KEY => fingerprint,
        'payment_option' => normalized.fetch('payment_option', 'now'),
        'zone' => booth_price.zone
      )

      kit = exhibitor.exhibitor_kits.create!(normalized.slice(*booking_fields).merge(
        exhibitor_booth_price: booth_price,
        booth_type: booth_price.booth_type,
        booth_quantity: 1,
        pic_email_address: exhibitor.vendor.email,
        amount_paid: price,
        price_snapshot: price,
        currency: 'MYR',
        payment_status: :unpaid,
        booking_status: :active,
        reservation_expires_at: normalized.fetch('payment_option', 'now') == 'later' ? RESERVATION_TTL.from_now : nil,
        idempotency_key: idempotency_key,
        custom_fields_data: custom_fields
      ))
      ExhibitorIcCopyAttacher.new(event: event, exhibitor_kit: kit,
        signed_id: normalized['ic_copy_signed_id']).call
      kit.ic_copy.attach(source.ic_copy.blob) if normalized['ic_copy_signed_id'].blank? && source&.ic_copy&.attached?
      [Result.new(kit: kit, idempotent_replay: false), new_user, password]
    end

    if new_user
      EmailDelivery::AuditedDelivery.deliver_now(
        mailer_name: 'PublicExhibitorWelcomeMailer', mailer_action: 'welcome',
        args: [new_user.email, password], related: new_user, metadata: {}, dedupe: true
      )
    end
    result
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
      if normalized['exhibitor_booth_price_id'].present? &&
         normalized['exhibitor_booth_price_id'].to_i != kit.exhibitor_booth_price_id
        booth_price = event.exhibitor_booth_prices.find(normalized['exhibitor_booth_price_id'])
        ExhibitorBookingCapacity.lock!(booth_price, quantity: kit.booth_quantity, excluding: kit)
        price = booth_price.current_price
        changes.merge!(exhibitor_booth_price: booth_price, booth_type: booth_price.booth_type,
          amount_paid: price * kit.booth_quantity, price_snapshot: price)
      end
      kit.update!(changes)
      kit
    end
  end

  private

  attr_reader :event, :access

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
    %w[company_name company_address name_on_fascia pic_full_name pic_position pic_contact_number country booth_number]
  end
end
