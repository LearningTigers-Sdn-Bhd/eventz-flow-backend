require 'rails_helper'

RSpec.describe ContractorPrintingServiceLinker, type: :service do
  let(:org_owner) { create(:user, :org_owner) }
  let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
  let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }

  describe '#link_if_needed' do
    context 'when allow_contractor_printing_services is true and contractor is assigned' do
      let(:event) { create(:event, allow_contractor_printing_services: true) }
      let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
      let!(:printing_service1) { create(:printing_service, user: contractor_user) }
      let!(:printing_service2) { create(:printing_service, user: contractor_user) }

      subject(:linker) { described_class.new(event: event) }

      it 'links contractor printing services to the event' do
        expect { linker.link_if_needed }.to change(EventPrintingService, :count).by(2)
      end

      it 'links the correct services' do
        linker.link_if_needed
        linked_ids = EventPrintingService.where(event: event).pluck(:printing_service_id)
        expect(linked_ids).to contain_exactly(printing_service1.id, printing_service2.id)
      end

      it 'does not create duplicates when called multiple times' do
        linker.link_if_needed
        expect { linker.link_if_needed }.to change(EventPrintingService, :count).by(0)
      end
    end

    context 'when allow_contractor_printing_services is false' do
      let(:event) { create(:event, allow_contractor_printing_services: false) }
      let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
      let!(:printing_service) { create(:printing_service, user: contractor_user) }

      subject(:linker) { described_class.new(event: event) }

      it 'does not link any printing services' do
        expect { linker.link_if_needed }.to change(EventPrintingService, :count).by(0)
      end
    end

    context 'when no contractor is assigned' do
      let(:event) { create(:event, allow_contractor_printing_services: true) }

      subject(:linker) { described_class.new(event: event) }

      it 'does not link any printing services' do
        expect { linker.link_if_needed }.to change(EventPrintingService, :count).by(0)
      end
    end
  end
end
