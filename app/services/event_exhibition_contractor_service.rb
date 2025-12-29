class EventExhibitionContractorService < BaseService
  attr_reader :event

  def initialize(user:, event:, params: {})
    super(user, params)
    @event = event
  end

  def create
    contractor = EventExhibitionContractor.new(create_params)
    authorize contractor, :create?

    ActiveRecord::Base.transaction do
      contractor.save!
      event.update!(use_exhibitor_kit: true)
      link_contractor_items_to_event(contractor)
    end

    ServiceResult.new(success: true, data: contractor, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.new(success: false, errors: e.record.errors.full_messages, status: :unprocessable_content)
  end

  private

  def create_params
    params.require(:event_exhibition_contractor).permit(:exhibition_contractor_profile_id).merge(event_id: event.id)
  end

  def link_contractor_items_to_event(contractor)
    contractor_user = contractor.exhibition_contractor_profile.user

    # Always link rentable items
    contractor_user.rentable_items.find_each do |item|
      EventRentableItem.find_or_create_by!(event: event, rentable_item: item)
    end

    # Only link printing services if allowed by event setting
    if event.allow_contractor_printing_services
      contractor_user.printing_services.find_each do |service|
        EventPrintingService.find_or_create_by!(event: event, printing_service: service)
      end
    end
  end
end
