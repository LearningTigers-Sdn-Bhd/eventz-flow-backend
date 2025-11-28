require 'rails_helper'

RSpec.describe EventExhibitionContractorService, type: :service do
  let(:event) { create(:event) }
  let(:organizer) { create(:user, :organizer) }
  let(:contractor_user) { create(:user, :exhibition_contractor) }
  let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
  let(:params) do
    {
      event_exhibition_contractor: {
        exhibition_contractor_profile_id: contractor_profile.id
      }
    }
  end

  subject(:service) { described_class.new(user: organizer, event: event, params: ActionController::Parameters.new(params)) }

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
  end
end
