class CatalogItemAvailabilityService < BaseService
  def initialize(user:, params: {})
    super(user, params)
  end

  def available_rentable_items
    RentableItem.active
  end

  def available_printing_services
    PrintingService.active
  end
end
