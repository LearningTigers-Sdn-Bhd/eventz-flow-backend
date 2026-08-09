require 'rails_helper'
require 'pundit/rspec'

RSpec.describe VendorPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:creator) { create(:user, :organizer) }
  let(:teammate) { create(:user, :organizer) }
  let(:outsider) { create(:user, :organizer) }
  let(:vendor) { create(:user, :vendor, created_by_id: creator.id) }

  before do
    create(:event_assignment, event: event, user: creator, role: :event_admin)
    create(:event_assignment, event: event, user: teammate, role: :event_admin)
  end

  describe 'Scope' do
    subject { described_class::Scope.new(actor, User.where(role: :vendor)).resolve }

    context 'vendor attached to the shared event' do
      before { create(:merchant, event: event, vendor: vendor) }

      context 'as the creator' do
        let(:actor) { creator }
        it { is_expected.to include(vendor) }
      end

      context 'as a teammate on the same event' do
        let(:actor) { teammate }
        it { is_expected.to include(vendor) }
      end

      context 'as an organizer with no shared event' do
        let(:actor) { outsider }
        it { is_expected.not_to include(vendor) }
      end
    end

    context 'vendor not attached to any event yet' do
      context 'as a teammate of the creator on some event' do
        let(:actor) { teammate }
        it { is_expected.to include(vendor) }
      end

      context 'as an organizer sharing no event with the creator' do
        let(:actor) { outsider }
        it { is_expected.not_to include(vendor) }
      end
    end

    context 'as an org owner' do
      let(:actor) { create(:user, :org_owner) }
      it { is_expected.to include(vendor) }
    end

    context 'vendor created by an org_owner who shares the event' do
      let(:org_owner_creator) { create(:user, :org_owner) }
      let(:vendor) { create(:user, :vendor, created_by_id: org_owner_creator.id) }
      let(:actor) { teammate }

      before { create(:event_assignment, event: event, user: org_owner_creator, role: :event_admin) }

      it 'does not leak via the org_owner staffing overlap' do
        expect(subject).not_to include(vendor)
      end
    end
  end

  describe 'actions' do
    subject { described_class.new(actor, vendor) }

    context 'teammate on the shared event' do
      let(:actor) { teammate }
      before { create(:merchant, event: event, vendor: vendor) }

      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:toggle_status) }
      it { is_expected.to permit_action(:destroy) }

      context 'when the vendor also belongs to an event the teammate does not staff' do
        before { create(:merchant, event: create(:event), vendor: vendor) }

        it { is_expected.to permit_action(:update) }
        it { is_expected.not_to permit_action(:destroy) }
      end
    end

    context 'teammate of the creator, vendor not attached to any event yet' do
      let(:actor) { teammate }

      it { is_expected.to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context 'organizer with no shared event' do
      let(:actor) { outsider }
      before { create(:merchant, event: event, vendor: vendor) }

      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context 'creator' do
      let(:actor) { creator }

      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:destroy) }
    end
  end
end
