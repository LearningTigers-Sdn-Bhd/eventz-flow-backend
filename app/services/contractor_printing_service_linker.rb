class ContractorPrintingServiceLinker
  def initialize(event:)
    @event = event
  end

  def link_if_needed
    return unless @event.allow_contractor_printing_services
    return unless @event.event_exhibition_contractor.present?

    contractor_user = @event.event_exhibition_contractor.exhibition_contractor_profile.user

    contractor_user.printing_services.find_each do |service|
      EventPrintingService.find_or_create_by(event: @event, printing_service: service)
    end
  end
end
