# frozen_string_literal: true

class EventVendorService
  class Result
    attr_reader :success, :data, :errors

    def initialize(success:, data: nil, errors: [])
      @success = success
      @data = data
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  # Create a vendor assignment for an event
  #
  # @param event [Event] The event to assign the vendor to
  # @param params [Hash] Vendor parameters (vendor_id, full_name, email, phone, password, password_confirmation, redirect_url, exhibitor_kit_attributes)
  def self.create(event:, params:, current_user:)
    raw_kit_attrs = params[:exhibitor_kit_attributes]
    voucher_requested = raw_kit_attrs.present? &&
      (raw_kit_attrs[:voucher_code] || raw_kit_attrs['voucher_code']).present?
    voucher = nil
    result = nil

    EventVendor.transaction do
      event.lock!

      # Determine vendor type based on event.use_ticket
      vendor_type = determine_vendor_type(event)
      exhibitor_kit_attrs = enrich_exhibitor_kit_attributes(
        event,
        params[:exhibitor_kit_attributes]
      ) { |matched_voucher| voucher = matched_voucher }
      if voucher && (
        vendor_type != 'Exhibitor' || existing_vendor_assignment?(event, params)
      )
        raise ExhibitorVoucherRedemption::VoucherMismatch,
          ExhibitorVoucherRedemption::MISMATCH_MESSAGE
      end

      # If vendor_id is provided, assign existing vendor
      result = if params[:vendor_id].present?
        assign_existing_vendor(event, params[:vendor_id], params, vendor_type, exhibitor_kit_attrs)
      else
        # Create new vendor user (only organizers can do this)
        if current_user.is_organizer?
          create_vendor_user(params, event, vendor_type, current_user, exhibitor_kit_attrs)
        else
          Result.new(success: false, errors: ['Only organizers can create new vendor users'])
        end
      end

      if result.success? && voucher
        unless result.data.is_a?(Exhibitor)
          raise ExhibitorVoucherRedemption::VoucherMismatch,
            ExhibitorVoucherRedemption::MISMATCH_MESSAGE
        end

        exhibitor_kit = result.data.exhibitor_kits.last
        unless exhibitor_kit
          raise ExhibitorVoucherRedemption::VoucherMismatch,
            ExhibitorVoucherRedemption::MISMATCH_MESSAGE
        end

        ExhibitorVoucherRedemption.redeem!(
          voucher: voucher,
          exhibitor_kit: exhibitor_kit
        )
      end
    end

    result
  rescue ExhibitorVoucherRedemption::InvalidVoucher,
         ExhibitorVoucherRedemption::VoucherMismatch => e
    Result.new(success: false, errors: [e.message])
  rescue ActiveRecord::RecordNotUnique
    message = if voucher_requested
      ExhibitorVoucherRedemption::MISMATCH_MESSAGE
    else
      'Vendor is already assigned to this event'
    end
    Result.new(success: false, errors: [message])
  end

  # Determine vendor type based on event.use_ticket or use_exhibitor_kit
  #
  # @param event [Event] The event
  # @return [String] 'Exhibitor' or 'Merchant'
  def self.determine_vendor_type(event)
    (event.use_ticket? || event.use_exhibitor_kit?) ? 'Exhibitor' : 'Merchant'
  end

  # Enrich exhibitor_kit_attributes with derived fields when caller supplies
  # an exhibitor_booth_price_id but omits booth_type / amount_paid.
  #
  # Mirrors public/exhibitor_registrations_controller.rb#build_exhibitor_kit_attributes:
  # booth_type/amount_paid are server-derived from the booth price so the
  # organizer assign form only needs to send exhibitor_booth_price_id.
  #
  # @param event [Event] The event
  # @param attrs [ActionController::Parameters, Hash, nil] Raw exhibitor_kit_attributes
  # @return [ActionController::Parameters, Hash, nil] Same shape, possibly with booth_type/amount_paid filled
  def self.enrich_exhibitor_kit_attributes(event, attrs)
    return attrs if attrs.blank?

    voucher_code = attrs.delete(:voucher_code) || attrs.delete('voucher_code')
    booth_price_id = attrs[:exhibitor_booth_price_id] || attrs['exhibitor_booth_price_id']
    if booth_price_id.blank? && voucher_code.present?
      raise ExhibitorVoucherRedemption::VoucherMismatch,
        ExhibitorVoucherRedemption::MISMATCH_MESSAGE
    end
    return attrs if booth_price_id.blank?

    booth_price = event.exhibitor_booth_prices.find_by(id: booth_price_id)
    if booth_price.nil? && voucher_code.present?
      raise ExhibitorVoucherRedemption::VoucherMismatch,
        ExhibitorVoucherRedemption::MISMATCH_MESSAGE
    end
    return attrs unless booth_price

    booth_type = attrs[:booth_type] || attrs['booth_type']
    if booth_type.blank?
      attrs[:booth_type] = booth_price.booth_type if attrs.respond_to?(:[]=)
    end

    qty = (attrs[:booth_quantity] || attrs['booth_quantity']).to_i
    qty = 1 if qty <= 0
    attrs[:booth_quantity] = qty if attrs.respond_to?(:[]=)

    package_id = attrs[:exhibitor_package_id] || attrs['exhibitor_package_id']
    package = package_id.present? ? event.exhibitor_packages.find_by(id: package_id) : nil
    # A package that does not belong to the chosen booth price is dropped, never mispriced.
    package = nil if package && !package.matches_booth_price?(booth_price.id)
    attrs[:exhibitor_package_id] = package&.id if attrs.respond_to?(:[]=)

    base_price = package&.price || booth_price.current_price
    voucher_result = ExhibitorVoucherRedemption.preview(
      event: event,
      code: voucher_code,
      booth_price: booth_price,
      package: package,
      base_price: base_price
    )
    yield voucher_result[:voucher] if block_given?

    amount_paid = attrs[:amount_paid] || attrs['amount_paid']
    if amount_paid.blank? || voucher_result[:voucher]
      unit_price = voucher_result[:price]
      if attrs.respond_to?(:[]=)
        attrs[:amount_paid] = unit_price * qty
        attrs[:price_snapshot] = unit_price
      end
    end

    attrs
  end



  # Assign existing vendor to event
  #
  # @param event [Event] The event
  # @param vendor_id [Integer] ID of existing vendor user
  # @param params [Hash] Additional parameters
  # @param vendor_type [String] 'Exhibitor' or 'Merchant'
  # @param exhibitor_kit_attributes [Hash] Attributes for ExhibitorKit
  # @return [Result] Result object with EventVendor record or errors
  def self.assign_existing_vendor(event, vendor_id, params, vendor_type, exhibitor_kit_attributes = nil)
    vendor_user = User.find_by(id: vendor_id, role: :vendor)
    unless vendor_user
      return Result.new(success: false, errors: ['Vendor not found'])
    end

    # Check if vendor is already assigned to this event
    existing_vendor = event.event_vendors.find_by(vendor: vendor_user)

    if existing_vendor
      # Update existing vendor attributes
      existing_vendor.redirect_url = params[:redirect_url] if params.key?(:redirect_url)
      existing_vendor.poster_url = params[:poster_url] if params.key?(:poster_url)
      existing_vendor.qr_url = params[:qr_url] if params.key?(:qr_url)

      # Update type if needed
      if existing_vendor.type != vendor_type
        # Type changed - update type column directly
        EventVendor.where(id: existing_vendor.id).update_all(type: vendor_type)
        existing_vendor.reload
      end

      if existing_vendor.save
        # Handle exhibitor_kit attributes if it's an Exhibitor
        if existing_vendor.is_a?(Exhibitor) && exhibitor_kit_attributes.present?
          existing_vendor.legacy_exhibitor_kit&.update(exhibitor_kit_attributes)
        end
        Result.new(success: true, data: existing_vendor.reload)
      else
        Result.new(success: false, errors: existing_vendor.errors.full_messages)
      end
    else
      # Create new vendor with appropriate type
      vendor_attributes = {
        redirect_url: params[:redirect_url],
        poster_url: params[:poster_url],
        qr_url: params[:qr_url]
      }

      if vendor_type == 'Exhibitor'
        vendor_attributes[:exhibitor_kits_attributes] = [exhibitor_kit_attributes] if exhibitor_kit_attributes.present?
        event_vendor = event.exhibitors.build(vendor_attributes.merge(vendor: vendor_user))
      else
        event_vendor = event.merchants.build(vendor_attributes.merge(vendor: vendor_user))
      end

      if event_vendor.save
        Result.new(success: true, data: event_vendor.is_a?(Exhibitor) ? EventVendor.exhibitors.includes(exhibitor_kits: [:exhibitor_team_members]).find(event_vendor.id) : event_vendor.reload)
      else
        Result.new(success: false, errors: event_vendor.errors.full_messages)
      end
    end
  end

  # Create new vendor user and assign to event
  #
  # @param params [Hash] Vendor parameters
  # @param event [Event] The event
  # @param vendor_type [String] 'Exhibitor' or 'Merchant'
  # @param creator [User] The user creating the vendor (optional for backward compatibility)
  # @param exhibitor_kit_attributes [Hash] Attributes for ExhibitorKit
  # @return [Result] Result object with EventVendor record or errors
  def self.create_vendor_user(params, event, vendor_type, creator = nil, exhibitor_kit_attributes = nil)
    email = params[:email].to_s.strip
    full_name = params[:full_name]
    password = params[:password]
    password_confirmation = params[:password_confirmation]
    phone = params[:phone]

    # Generate email if not provided
    if email.blank?
      email = generate_vendor_email(event, full_name)
    end

    # Look up user by email (case-insensitive)
    user = User.find_by('LOWER(email) = ?', email.downcase)

    # Create user if doesn't exist
    unless user
      user_attrs = {
        email: email,
        full_name: full_name,
        password: password,
        password_confirmation: password_confirmation,
        phone: phone,
        email_verified_at: Time.current, # Bypass email verification
        role: :vendor,
        status: :active
      }
      
      # Add created_by_id if creator is provided
      user_attrs[:created_by_id] = creator.id if creator.present?
      
      user = User.new(user_attrs)

      unless user.save
        return Result.new(success: false, errors: user.errors.full_messages)
      end
    else
      # User exists, check if they're a vendor
      unless user.vendor?
        return Result.new(success: false, errors: ['User exists but is not a vendor'])
      end
    end

    # Check if vendor is already assigned to this event
    existing_vendor = event.event_vendors.find_by(vendor: user)

    if existing_vendor
      # Update existing vendor attributes
      existing_vendor.redirect_url = params[:redirect_url] if params.key?(:redirect_url)
      existing_vendor.poster_url = params[:poster_url] if params.key?(:poster_url)
      existing_vendor.qr_url = params[:qr_url] if params.key?(:qr_url)

      # Update type if needed
      if existing_vendor.type != vendor_type
        # Type changed - update type column directly
        EventVendor.where(id: existing_vendor.id).update_all(type: vendor_type)
        existing_vendor.reload
      end

      if existing_vendor.save
        # Handle exhibitor_kit attributes if it's an Exhibitor
        if existing_vendor.is_a?(Exhibitor) && exhibitor_kit_attributes.present?
          existing_vendor.legacy_exhibitor_kit&.update(exhibitor_kit_attributes)
        end
        Result.new(success: true, data: existing_vendor.reload)
      else
        Result.new(success: false, errors: existing_vendor.errors.full_messages)
      end
    else
      # Create new vendor with appropriate type
      vendor_attributes = {
        redirect_url: params[:redirect_url],
        poster_url: params[:poster_url],
        qr_url: params[:qr_url]
      }

      if vendor_type == 'Exhibitor'
        vendor_attributes[:exhibitor_kits_attributes] = [exhibitor_kit_attributes] if exhibitor_kit_attributes.present?
        event_vendor = event.exhibitors.build(vendor_attributes.merge(vendor: user))
      else
        event_vendor = event.merchants.build(vendor_attributes.merge(vendor: user))
      end

      if event_vendor.save
        Result.new(success: true, data: event_vendor.is_a?(Exhibitor) ? EventVendor.exhibitors.includes(exhibitor_kits: [:exhibitor_team_members]).find(event_vendor.id) : event_vendor.reload)
      else
        Result.new(success: false, errors: event_vendor.errors.full_messages)
      end
    end
  end


  # Generate vendor email: vendor_{slug_event_name}_{sanitized_first_name}_{increment}@eventzflow.com
  #
  # @param event [Event] The event
  # @param full_name [String] The vendor's full name
  # @return [String] Generated email address
  def self.generate_vendor_email(event, full_name)
    event_slug = slugify(event.title)
    first_name = extract_first_name(full_name)
    base_email = "vendor_#{event_slug}_#{first_name}@eventzflow.com"

    find_next_available_email(base_email)
  end

  private

  def self.existing_vendor_assignment?(event, params)
    vendor_id = params[:vendor_id]
    if vendor_id.blank? && params[:email].present?
      vendor_id = User.find_by('LOWER(email) = ?', params[:email].to_s.strip.downcase)&.id
    end

    vendor_id.present? && event.event_vendors.exists?(vendor_id: vendor_id)
  end

  # Convert text to URL-friendly slug
  #
  # @param text [String] Text to convert to slug
  # @return [String] Slugified text
  def self.slugify(text)
    text.to_s.downcase
        .gsub(/[^a-z0-9\s-]/, '') # Remove special characters
        .gsub(/\s+/, '_')          # Replace spaces with underscores
        .gsub(/-+/, '_')           # Replace hyphens with underscores
        .gsub(/_+/, '_')           # Replace multiple underscores with single
        .gsub(/^_|_$/, '')         # Remove leading/trailing underscores
  end

  # Extract first name from full name
  #
  # @param full_name [String] Full name
  # @return [String] Slugified first name
  def self.extract_first_name(full_name)
    first_word = full_name.to_s.split.first || 'vendor'
    slugify(first_word)
  end

  # Find next available email with increment
  #
  # @param base_email [String] Base email address
  # @return [String] Available email address
  # @raise [StandardError] If too many duplicates exist
  def self.find_next_available_email(base_email)
    # Try base email first (without increment)
    return base_email unless User.exists?(['LOWER(email) = ?', base_email.downcase])

    # If base email exists, try with increments
    base_without_domain = base_email.split('@').first
    counter = 0

    loop do
      email = "#{base_without_domain}_#{format('%02d', counter)}@eventzflow.com"
      return email unless User.exists?(['LOWER(email) = ?', email.downcase])

      counter += 1

      # Safety check to prevent infinite loop
      if counter > 999
        raise 'Too many duplicate emails. Please provide a unique email.'
      end
    end
  end
end
