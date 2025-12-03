require 'rails_helper'

RSpec.describe ExhibitorKitPricingService, type: :service do
  let(:user) { create(:user) }
  let(:service) { ExhibitorKitPricingService.new(user: user) }
  let(:event) { create(:event) }
  let(:rentable_item) { create(:rentable_item) }
  let(:printing_service) { create(:printing_service) }

  describe '#resolve_item_price' do
    context 'when a valid price tier exists' do
      let(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }
      let!(:price_tier) do
        create(:event_rentable_item_price_tier, event_rentable_item: event_rentable_item,
                                                price: 100.00, start_date: 1.day.ago, end_date: 1.day.from_now)
      end

      it 'returns the price of the applicable tier' do
        result = service.resolve_item_price(event_rentable_item.id)
        expect(result.success?).to be(true)
        expect(result.data).to eq(100.00)
      end
    end

    context 'when no valid price tier exists' do
      let(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }

      it 'returns an error' do
        result = service.resolve_item_price(event_rentable_item.id)
        expect(result.success?).to be(false)
        expect(result.errors).to eq('No price tier found for this item')
        expect(result.status).to eq(:not_found)
      end
    end

    context 'when the event_rentable_item does not exist' do
      it 'raises an ActiveRecord::RecordNotFound error' do
        expect { service.resolve_item_price(-1) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#resolve_printing_price' do
    context 'when a valid price tier exists' do
      let(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }
      let!(:price_tier) do
        create(:event_printing_service_price_tier, event_printing_service: event_printing_service,
                                                   price: 50.00, start_date: 1.day.ago, end_date: 1.day.from_now)
      end

      it 'returns the price of the applicable tier' do
        result = service.resolve_printing_price(event_printing_service.id)
        expect(result.success?).to be(true)
        expect(result.data).to eq(50.00)
      end
    end

    context 'when no valid price tier exists' do
      let(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }

      it 'returns an error' do
        result = service.resolve_printing_price(event_printing_service.id)
        expect(result.success?).to be(false)
        expect(result.errors).to eq('No price tier found for this printing service')
        expect(result.status).to eq(:not_found)
      end
    end

    context 'when the event_printing_service does not exist' do
      it 'raises an ActiveRecord::RecordNotFound error' do
        expect { service.resolve_printing_price(-1) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
