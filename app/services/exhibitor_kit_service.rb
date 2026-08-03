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

    if exhibitor_kit.update(permitted_params)
      exhibitor_kit.reload
      ServiceResult.new(success: true, data: exhibitor_kit, status: :ok)
    else
      ServiceResult.new(success: false, errors: exhibitor_kit.errors.full_messages, status: :unprocessable_content)
    end
  rescue CustomError::Forbidden => e
    ServiceResult.new(success: false, errors: e.message, status: e.status)
  end

  private

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
