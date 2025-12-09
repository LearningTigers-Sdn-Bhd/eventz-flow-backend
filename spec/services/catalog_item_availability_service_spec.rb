require 'rails_helper'

RSpec.describe CatalogItemAvailabilityService, type: :service do
  let(:user) { create(:user) }
  let(:service) { CatalogItemAvailabilityService.new(user: user) }

  describe '#available_rentable_items' do
    let!(:active_item1) { create(:rentable_item, status: :active) }
    let!(:active_item2) { create(:rentable_item, status: :active) }
    let!(:inactive_item) { create(:rentable_item, status: :inactive) }

    it 'returns only active rentable items' do
      expect(service.available_rentable_items).to match_array([active_item1, active_item2])
    end
  end

  describe '#available_printing_services' do
    let!(:active_service1) { create(:printing_service, status: :active) }
    let!(:active_service2) { create(:printing_service, status: :active) }
    let!(:inactive_service) { create(:printing_service, status: :inactive) }

    it 'returns only active printing services' do
      expect(service.available_printing_services).to match_array([active_service1, active_service2])
    end
  end
end
