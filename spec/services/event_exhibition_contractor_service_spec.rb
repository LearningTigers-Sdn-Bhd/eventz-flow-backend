require 'rails_helper'

RSpec.describe EventExhibitionContractorService, type: :service do
    let(:org_owner) { create(:user, :org_owner) }
    let(:event) { create(:event) }
    let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
    let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
  let(:params) do
    {
      event_exhibition_contractor: {
        exhibition_contractor_profile_id: contractor_profile.id
      }
    }
  end

  subject(:service) { described_class.new(user: org_owner, event: event, params: ActionController::Parameters.new(params)) }

  describe '#create' do
    it 'creates an event exhibition contractor' do
      expect { service.create }.to change(EventExhibitionContractor, :count).by(1)
    end

    it 'enables use_exhibitor_kit on the event' do
      service.create
      expect(event.reload.use_exhibitor_kit).to be(true)
    end

    it 'returns a successful service result' do
      result = service.create
      expect(result).to be_a(BaseService::ServiceResult)
      expect(result).to be_success
      expect(result.data).to be_a(EventExhibitionContractor)
      expect(result.status).to eq(:created)
    end

    context 'when the user is not authorized' do
      let(:unauthorized_user) { create(:user, :vendor) }
      subject(:service) { described_class.new(user: unauthorized_user, event: event, params: ActionController::Parameters.new(params)) }

      it 'raises a Pundit::NotAuthorizedError' do
        expect { service.create }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when contractor has rentable items' do
      let!(:rentable_item1) { create(:rentable_item, user: contractor_user) }
      let!(:rentable_item2) { create(:rentable_item, user: contractor_user) }

      it 'auto-links all rentable items to the event' do
        expect { service.create }.to change(EventRentableItem, :count).by(2)
      end

      it 'links the correct items to the event' do
        service.create
        linked_item_ids = EventRentableItem.where(event: event).pluck(:rentable_item_id)
        expect(linked_item_ids).to contain_exactly(rentable_item1.id, rentable_item2.id)
      end
    end

    context 'when contractor has printing services' do
      let(:event) { create(:event, allow_contractor_printing_services: true) }
      let!(:printing_service1) { create(:printing_service, user: contractor_user) }
      let!(:printing_service2) { create(:printing_service, user: contractor_user) }

      it 'auto-links all printing services to the event' do
        expect { service.create }.to change(EventPrintingService, :count).by(2)
      end

      it 'links the correct services to the event' do
        service.create
        linked_service_ids = EventPrintingService.where(event: event).pluck(:printing_service_id)
        expect(linked_service_ids).to contain_exactly(printing_service1.id, printing_service2.id)
      end
    end

    context 'when contractor has both rentable items and printing services' do
      let(:event) { create(:event, allow_contractor_printing_services: true) }
      let!(:rentable_item) { create(:rentable_item, user: contractor_user) }
      let!(:printing_service) { create(:printing_service, user: contractor_user) }

      it 'auto-links all items and services to the event' do
        expect { service.create }
          .to change(EventRentableItem, :count).by(1)
          .and change(EventPrintingService, :count).by(1)
      end
    end

    context 'when contractor has no items or services' do
      it 'creates contractor without linking any items' do
        expect { service.create }
          .to change(EventExhibitionContractor, :count).by(1)
          .and change(EventRentableItem, :count).by(0)
          .and change(EventPrintingService, :count).by(0)
      end
    end

    context 'when allow_contractor_printing_services is false' do
      let(:event) { create(:event, allow_contractor_printing_services: false) }
      let!(:rentable_item) { create(:rentable_item, user: contractor_user) }
      let!(:printing_service) { create(:printing_service, user: contractor_user) }

      it 'links rentable items but not printing services' do
        expect { service.create }
          .to change(EventRentableItem, :count).by(1)
          .and change(EventPrintingService, :count).by(0)
      end
    end

    context 'when allow_contractor_printing_services is true' do
      let(:event) { create(:event, allow_contractor_printing_services: true) }
      let!(:rentable_item) { create(:rentable_item, user: contractor_user) }
      let!(:printing_service) { create(:printing_service, user: contractor_user) }

      it 'links both rentable items and printing services' do
        expect { service.create }
          .to change(EventRentableItem, :count).by(1)
          .and change(EventPrintingService, :count).by(1)
      end
    end
  end
end
