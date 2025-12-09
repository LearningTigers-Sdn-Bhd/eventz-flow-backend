class ExhibitorKitService < BaseService
  attr_reader :event, :user

  def initialize(user:, event: nil, params: {})
    super(user, params)
    @user = user
    @event = event
  end

  def create
    event_vendor = event.event_vendors.find_by(id: params.dig(:exhibitor_kit, :event_vendor_id), type: 'Exhibitor')
    return ServiceResult.new(success: false, errors: 'Exhibitor not found for this event', status: :not_found) if event_vendor.nil?

    permitted = create_params

    exhibitor_kit = event_vendor.build_exhibitor_kit(permitted)
    authorize exhibitor_kit, :create?

    if exhibitor_kit.save
      ServiceResult.new(success: true, data: exhibitor_kit, status: :created)
    else
      ServiceResult.new(success: false, errors: exhibitor_kit.errors.full_messages, status: :unprocessable_content)
    end
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
      ServiceResult.new(success: true, data: exhibitor_kit, status: :ok)
    else
      ServiceResult.new(success: false, errors: exhibitor_kit.errors.full_messages, status: :unprocessable_content)
    end
  rescue CustomError::Forbidden => e
    ServiceResult.new(success: false, errors: e.message, status: e.status)
  end

  private

  def create_params
    event_vendor = EventVendor.find_by(id: params.dig(:exhibitor_kit, :event_vendor_id))
    params.require(:exhibitor_kit).permit(*policy(ExhibitorKit.new(event_vendor: event_vendor)).permitted_attributes_for_create)
  end

  def update_params(exhibitor_kit)
    raw_params = params.require(:exhibitor_kit)
    permitted_attrs = policy(exhibitor_kit).permitted_attributes_for_update

    # Removed auto-fill logic for debugging strong parameters. Will restore later.

    permitted_params = raw_params.permit(*permitted_attrs)
    { permitted_params: permitted_params, raw_params_keys: raw_params.keys.map(&:to_s) }
  end
end
