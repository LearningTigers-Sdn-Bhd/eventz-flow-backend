class ExhibitorKitPricingService < BaseService
  def initialize(user:, params: {})
    super(user, params)
  end

  def resolve_item_price(event_rentable_item_id)
    event_rentable_item = EventRentableItem.find(event_rentable_item_id)
    # Logic to find the applicable price tier based on current date and event_rentable_item
    # For simplicity, let's assume the first available price tier is chosen.
    price_tier = event_rentable_item.event_rentable_item_price_tiers.where('start_date <= ? AND (end_date >= ? OR end_date IS NULL)', Time.current, Time.current).first

    if price_tier
      BaseService::ServiceResult.new(success: true, data: price_tier.price, status: :ok)
    else
      BaseService::ServiceResult.new(success: false, errors: 'No price tier found for this item', status: :not_found)
    end
  end

  def resolve_printing_price(event_printing_service_id)
    event_printing_service = EventPrintingService.find(event_printing_service_id)
    # Logic to find the applicable price tier based on current date and event_printing_service
    # For simplicity, let's assume the first available price tier is chosen.
    price_tier = event_printing_service.event_printing_service_price_tiers.where('start_date <= ? AND (end_date >= ? OR end_date IS NULL)', Time.current, Time.current).first

    if price_tier
      BaseService::ServiceResult.new(success: true, data: price_tier.price, status: :ok)
    else
      BaseService::ServiceResult.new(success: false, errors: 'No price tier found for this printing service', status: :not_found)
    end
  end
end
