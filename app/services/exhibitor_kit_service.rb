class ExhibitorKitService < BaseService
  attr_reader :event

  def initialize(user:, event: nil, params: {})
    super(user, params)
    @event = event
  end

  def create
    event_vendor = event.event_vendors.find_by(id: params.dig(:exhibitor_kit, :event_vendor_id), type: 'Exhibitor')
    return ServiceResult.new(success: false, errors: 'Exhibitor not found for this event', status: :not_found) if event_vendor.nil?

    permitted = create_params
    puts "Create permitted params: #{permitted.inspect}"

    exhibitor_kit = event_vendor.build_exhibitor_kit(permitted)
    authorize exhibitor_kit, :create?

    if exhibitor_kit.save
      ServiceResult.new(success: true, data: exhibitor_kit, status: :created)
    else
      ServiceResult.new(success: false, errors: exhibitor_kit.errors.full_messages, status: :unprocessable_entity)
    end
  end

  def update(exhibitor_kit)
    authorize exhibitor_kit, :update?

    permitted = update_params(exhibitor_kit)
    puts "Update permitted params: #{permitted.inspect}"

    if exhibitor_kit.update(permitted)
      ServiceResult.new(success: true, data: exhibitor_kit, status: :ok)
    else
      ServiceResult.new(success: false, errors: exhibitor_kit.errors.full_messages, status: :unprocessable_entity)
    end
  end

  private

  def create_params
    event_vendor = EventVendor.find_by(id: params.dig(:exhibitor_kit, :event_vendor_id))
    permitted = params.require(:exhibitor_kit).permit(*policy(ExhibitorKit.new(event_vendor: event_vendor)).permitted_attributes_for_create)
    puts "Policy permitted_attributes_for_create for create: #{policy(ExhibitorKit.new(event_vendor: event_vendor)).permitted_attributes_for_create.inspect}"
    permitted
  end

  def update_params(exhibitor_kit)
    permitted = params.require(:exhibitor_kit).permit(*policy(exhibitor_kit).permitted_attributes_for_update)
    puts "Policy permitted_attributes_for_update for update: #{policy(exhibitor_kit).permitted_attributes_for_update.inspect}"
    permitted
  end
end
