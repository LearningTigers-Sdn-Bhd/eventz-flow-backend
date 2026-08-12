class ExhibitorKitService < BaseService
  attr_reader :event, :user

  def initialize(user:, event: nil, params: {})
    super(user, params)
    @user = user
    @event = event
  end

  def create
    event_vendor = event.event_vendors.find_by(id: params.dig(:exhibitor_kit, :event_vendor_id), type: 'Exhibitor')
    if event_vendor.nil?
      return ServiceResult.new(success: false, errors: 'Exhibitor not found for this event',
                               status: :not_found)
    end

    permitted = create_params

    exhibitor_kit = event_vendor.exhibitor_kits.build(permitted.except(:voucher_code))
    authorize exhibitor_kit, :create?

    ExhibitorKit.transaction do
      event.lock!
      booth_price = event.exhibitor_booth_prices.find(permitted[:exhibitor_booth_price_id])
      quantity = 1
      ExhibitorBookingCapacity.lock!(booth_price, quantity: quantity)
      package = if permitted[:exhibitor_package_id].present?
        event.exhibitor_packages.find(permitted[:exhibitor_package_id])
      end
      raise ActiveRecord::RecordNotFound if package && !package.matches_booth_price?(booth_price.id)

      ExhibitorBookingCapacity.lock_package!(package, quantity: quantity) if package
      base_price = package&.price || booth_price.current_price
      voucher_result = ExhibitorVoucherRedemption.preview(
        event: event,
        code: permitted[:voucher_code],
        booth_price: booth_price,
        package: package,
        base_price: base_price
      )
      price = voucher_result[:price]
      exhibitor_kit.assign_attributes(
        exhibitor_booth_price: booth_price,
        exhibitor_package: package,
        booth_type: booth_price.booth_type,
        booth_quantity: quantity,
        amount_paid: price * quantity,
        price_snapshot: price,
        currency: 'MYR',
        payment_status: :unpaid,
        booking_status: :active,
        reservation_expires_at: nil
      )
      exhibitor_kit.save!
      if voucher_result[:voucher]
        ExhibitorVoucherRedemption.redeem!(
          voucher: voucher_result[:voucher],
          exhibitor_kit: exhibitor_kit
        )
      end
    end
    ServiceResult.new(success: true, data: exhibitor_kit, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.new(success: false, errors: e.record.errors.full_messages, status: :unprocessable_content)
  rescue ExhibitorBookingCapacity::SoldOut
    ServiceResult.new(success: false, errors: 'Booth capacity is sold out', status: :unprocessable_content)
  rescue ExhibitorVoucherRedemption::InvalidVoucher, ExhibitorVoucherRedemption::VoucherMismatch => e
    ServiceResult.new(success: false, errors: e.message, status: :unprocessable_content)
  end

  BOOKING_SELECTION_KEYS = %w[exhibitor_booth_price_id exhibitor_package_id voucher_code].freeze

  def update(exhibitor_kit)
    authorize exhibitor_kit, :update?

    permitted_data = update_params(exhibitor_kit)
    permitted_params = permitted_data[:permitted_params]
    raw_params_keys = permitted_data[:raw_params_keys]

    # Check for forbidden attributes if the user is not an admin/organizer
    unless user.is_org_owner_or_organizer? || user.is_event_admin?(exhibitor_kit.event)
      # Compare the keys from the original request params with the keys that actually passed strong parameters
      unpermitted_attributes = raw_params_keys - permitted_params.keys.map(&:to_s)

      if unpermitted_attributes.any?
        raise CustomError::Forbidden.new("You are not authorized to update: #{unpermitted_attributes.join(', ')}")
      end
    end

    if BOOKING_SELECTION_KEYS.any? { |key| permitted_params.key?(key) }
      update_booking_selection(exhibitor_kit, permitted_params)
    else
      persist(exhibitor_kit, permitted_params)
    end
  rescue CustomError::Forbidden => e
    ServiceResult.new(success: false, errors: e.message, status: e.status)
  end

  private

  def persist(exhibitor_kit, permitted_params)
    if exhibitor_kit.update(permitted_params)
      exhibitor_kit.reload
      ServiceResult.new(success: true, data: exhibitor_kit, status: :ok)
    else
      ServiceResult.new(success: false, errors: exhibitor_kit.errors.full_messages, status: :unprocessable_content)
    end
  end

  # Changing booth price / package / voucher re-runs the same pricing + capacity logic as
  # #create (recompute price_snapshot/amount_paid, re-lock capacity excluding this kit,
  # revalidate package-vs-booth-price zone match and voucher-vs-selection match), plus
  # cleanup #create never has to do: releasing a previously assigned physical booth when
  # the price tier changes, and returning a previously-applied voucher to the pool when
  # it's swapped or removed. Blocked once the kit is settled (paid/waived/sponsored) —
  # there is no refund/reconciliation flow for a price change after money has moved.
  def update_booking_selection(exhibitor_kit, permitted_params)
    if exhibitor_kit.settled?
      return ServiceResult.new(
        success: false,
        errors: 'Cannot change booth price, package, or voucher after the kit is settled',
        status: :unprocessable_content
      )
    end

    other_params = permitted_params.except(*BOOKING_SELECTION_KEYS)
    new_booth_price_id = permitted_params.key?('exhibitor_booth_price_id') ? permitted_params['exhibitor_booth_price_id'] : exhibitor_kit.exhibitor_booth_price_id
    new_package_id = permitted_params.key?('exhibitor_package_id') ? permitted_params['exhibitor_package_id'] : exhibitor_kit.exhibitor_package_id
    new_voucher_code = permitted_params.key?('voucher_code') ? permitted_params['voucher_code'] : exhibitor_kit.applied_voucher&.code
    quantity = [exhibitor_kit.booth_quantity.to_i, 1].max

    ExhibitorKit.transaction do
      event.lock!
      booth_price = event.exhibitor_booth_prices.find(new_booth_price_id)
      ExhibitorBookingCapacity.lock!(booth_price, quantity: quantity, excluding: exhibitor_kit)

      package = new_package_id.present? ? event.exhibitor_packages.find(new_package_id) : nil
      raise ActiveRecord::RecordNotFound if package && !package.matches_booth_price?(booth_price.id)

      ExhibitorBookingCapacity.lock_package!(package, quantity: quantity, excluding: exhibitor_kit) if package

      base_price = package&.price || booth_price.current_price
      voucher_result = ExhibitorVoucherRedemption.preview(
        event: event, code: new_voucher_code, booth_price: booth_price, package: package, base_price: base_price
      )

      old_voucher = exhibitor_kit.applied_voucher
      if old_voucher && old_voucher != voucher_result[:voucher]
        old_voucher.update!(status: :active, redeemed_by_exhibitor_kit: nil, redeemed_at: nil)
        # has_one autosave would otherwise re-link this stale cached target's FK back to
        # exhibitor_kit.id when #save! runs below — drop the cache now that it's released.
        exhibitor_kit.association(:applied_voucher).reset
      end

      if exhibitor_kit.exhibitor_booth_price_id != booth_price.id
        exhibitor_kit.exhibitor_booths.update_all(status: :available, exhibitor_kit_id: nil)
        other_params = other_params.merge('booth_number' => nil) unless other_params.key?('booth_number')
      end

      exhibitor_kit.assign_attributes(
        other_params.merge(
          exhibitor_booth_price: booth_price,
          exhibitor_package: package,
          booth_type: booth_price.booth_type,
          amount_paid: voucher_result[:price] * quantity,
          price_snapshot: voucher_result[:price]
        )
      )
      exhibitor_kit.save!

      if voucher_result[:voucher] && voucher_result[:voucher] != old_voucher
        ExhibitorVoucherRedemption.redeem!(voucher: voucher_result[:voucher], exhibitor_kit: exhibitor_kit)
      end
    end

    exhibitor_kit.reload
    ServiceResult.new(success: true, data: exhibitor_kit, status: :ok)
  rescue ActiveRecord::RecordNotFound
    ServiceResult.new(success: false, errors: 'Booth price or package not found', status: :unprocessable_content)
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.new(success: false, errors: e.record.errors.full_messages, status: :unprocessable_content)
  rescue ExhibitorBookingCapacity::SoldOut
    ServiceResult.new(success: false, errors: 'Booth capacity is sold out', status: :unprocessable_content)
  rescue ExhibitorVoucherRedemption::InvalidVoucher, ExhibitorVoucherRedemption::VoucherMismatch => e
    ServiceResult.new(success: false, errors: e.message, status: :unprocessable_content)
  end

  def create_params
    event_vendor = event.event_vendors.exhibitors.find_by(id: params.dig(:exhibitor_kit, :event_vendor_id))
    permitted_attributes = policy(ExhibitorKit.new(event_vendor: event_vendor)).permitted_attributes_for_create
    params.require(:exhibitor_kit).permit(*permitted_attributes, :exhibitor_package_id)
  end

  def update_params(exhibitor_kit)
    raw_params = params.require(:exhibitor_kit)
    permitted_attrs = policy(exhibitor_kit).permitted_attributes_for_update

    # Removed auto-fill logic for debugging strong parameters. Will restore later.

    permitted_params = raw_params.permit(*permitted_attrs)
    { permitted_params: permitted_params, raw_params_keys: raw_params.keys.map(&:to_s) }
  end
end
