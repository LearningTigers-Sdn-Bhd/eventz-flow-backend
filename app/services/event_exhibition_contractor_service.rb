class EventExhibitionContractorService < BaseService
  attr_reader :event

  def initialize(user:, event:, params: {})
    super(user, params)
    @event = event
  end

  def create
    contractor = EventExhibitionContractor.new(create_params)
    authorize contractor, :create?

    if contractor.save
      event.update(use_exhibitor_kit: true)
      ServiceResult.new(success: true, data: contractor, status: :created)
    else
      ServiceResult.new(success: false, errors: contractor.errors.full_messages, status: :unprocessable_content)
    end
  end

  private

  def create_params
    params.require(:event_exhibition_contractor).permit(:exhibition_contractor_profile_id).merge(event_id: event.id)
  end
end
