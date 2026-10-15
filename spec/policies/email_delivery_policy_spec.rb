require 'rails_helper'

RSpec.describe EmailDeliveryPolicy, type: :policy do
  subject { described_class }

  let(:owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }

  permissions :index?, :show?, :summary?, :settings?, :update_settings? do
    it { is_expected.to permit(owner, EmailDelivery) }
    it { is_expected.not_to permit(organizer, EmailDelivery) }
    it { is_expected.not_to permit(member, EmailDelivery) }
  end

  describe 'Scope' do
    it 'shows all rows to org owners and none to everyone else' do
      delivery = create(:email_delivery)

      expect(described_class::Scope.new(owner, EmailDelivery).resolve).to include(delivery)
      expect(described_class::Scope.new(organizer, EmailDelivery).resolve).to be_empty
    end
  end
end
