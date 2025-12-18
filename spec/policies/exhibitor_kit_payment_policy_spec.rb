require 'rails_helper'

RSpec.describe ExhibitorKitPaymentPolicy, type: :policy do
  let(:admin) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:exhibition_contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
  let(:exhibitor_user) { create(:user, :vendor) }
  let(:other_user) { create(:user) }

  let(:event) { create(:event, user: organizer) } # Organizer creates the event
  let(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }
  let(:exhibitor_kit_payment) { create(:exhibitor_kit_payment, exhibitor_kit: exhibitor_kit, payee: organizer) }

  describe 'ExhibitorKitPayment permissions' do
    context 'Admin permissions' do
      subject { ExhibitorKitPaymentPolicy.new(admin, exhibitor_kit_payment) }

      it { should permit_action(:index) }
      it { should permit_action(:show) }
      it { should permit_action(:create) }
      it { should permit_action(:update) }
      it { should permit_action(:destroy) }
      it { should permit_action(:verify) }
    end

    context 'Organizer permissions' do
      subject { ExhibitorKitPaymentPolicy.new(organizer, exhibitor_kit_payment) }

      it { should permit_action(:index) }
      it { should permit_action(:show) }
      it { should permit_action(:create) } # Assuming organizer can create payments for their events
      it { should permit_action(:update) }
      it { should permit_action(:destroy) }
      it { should permit_action(:verify) }
    end

    context 'Exhibition Contractor permissions' do
      # Set up context-specific data
      let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
      let(:contractor_event) { create(:event) }
      let!(:event_contractor_assignment) { create(:event_exhibition_contractor, event: contractor_event, exhibition_contractor_profile: contractor_user.reload.exhibition_contractor_profile) }
      let(:contractor_exhibitor_kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: contractor_event)) } # ExhibitorKit linked to contractor_event
      let(:payment_to_contractor) { create(:exhibitor_kit_payment, exhibitor_kit: contractor_exhibitor_kit, payee: contractor_user) } # Payment where contractor is payee

      subject { ExhibitorKitPaymentPolicy.new(contractor_user, payment_to_contractor) }

      it { should permit_action(:index) }
      it { should permit_action(:show) }
      it { should_not permit_action(:create) } # Contractor should not create
      it { should permit_action(:update) }
      it { should_not permit_action(:destroy) } # Contractor should not destroy
      it { should permit_action(:verify) }
    end

    context 'Exhibitor permissions' do
      subject { ExhibitorKitPaymentPolicy.new(exhibitor_user, exhibitor_kit_payment) }

      it { should permit_action(:index) }
      it { should permit_action(:show) }
      it { should permit_action(:create) }

      it 'permits update for their own pending payments' do
        pending_payment = create(:exhibitor_kit_payment, status: :pending, exhibitor_kit: exhibitor_kit, payee: organizer)
        expect(ExhibitorKitPaymentPolicy.new(exhibitor_user, pending_payment)).to permit_action(:update)
      end

      it 'forbids update for non-pending payments' do
        verified_payment = create(:exhibitor_kit_payment, :verified, exhibitor_kit: exhibitor_kit, payee: organizer)
        expect(ExhibitorKitPaymentPolicy.new(exhibitor_user, verified_payment)).to_not permit_action(:update)
      end

      it 'forbids destroy for verified payments' do
        verified_payment = create(:exhibitor_kit_payment, :verified, exhibitor_kit: exhibitor_kit, payee: organizer)
        expect(ExhibitorKitPaymentPolicy.new(exhibitor_user, verified_payment)).to_not permit_action(:destroy)
      end

      it 'permits destroy for pending payments' do
        pending_payment = create(:exhibitor_kit_payment, status: :pending, exhibitor_kit: exhibitor_kit, payee: organizer)
        expect(ExhibitorKitPaymentPolicy.new(exhibitor_user, pending_payment)).to permit_action(:destroy)
      end

      it { should_not permit_action(:verify) }
    end

    context 'Other User permissions' do
      subject { ExhibitorKitPaymentPolicy.new(other_user, exhibitor_kit_payment) }

      it { should_not permit_action(:index) }
      it { should_not permit_action(:show) }
      it { should_not permit_action(:create) }
      it { should_not permit_action(:update) }
      it { should_not permit_action(:destroy) }
      it { should_not permit_action(:verify) }
    end
  end

  describe 'Scope' do
    let!(:payment_organizer) { create(:exhibitor_kit_payment, exhibitor_kit: exhibitor_kit, payee: organizer) }

    # Setup for contractor
    let(:exhibition_contractor_event) { create(:event, user: exhibition_contractor_user) }
    let(:exhibition_contractor_exhibitor) { create(:exhibitor, event: exhibition_contractor_event) }
    let(:exhibition_contractor_exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibition_contractor_exhibitor) }
    let!(:payment_contractor) { create(:exhibitor_kit_payment, exhibitor_kit: exhibition_contractor_exhibitor_kit, payee: exhibition_contractor_user) }

    # Setup for another event not related to current user
    let(:another_organizer) { create(:user, :organizer) }
    let(:another_event) { create(:event, user: another_organizer) }
    let(:another_exhibitor) { create(:exhibitor, event: another_event) }
    let(:another_exhibitor_kit) { create(:exhibitor_kit, event_vendor: another_exhibitor) }
    let!(:payment_another) { create(:exhibitor_kit_payment, exhibitor_kit: another_exhibitor_kit, payee: another_organizer) }

    it 'Admin sees all payments' do
      expect(Pundit.policy_scope!(admin, ExhibitorKitPayment).to_a).to match_array([payment_organizer, payment_contractor, payment_another])
    end

    it 'Organizer sees payments for their events' do
      expect(Pundit.policy_scope!(organizer, ExhibitorKitPayment).to_a).to match_array([payment_organizer])
    end

    it 'Contractor sees payments for events they are associated with' do
      # Ensure the contractor is assigned to the event of payment_contractor's exhibitor_kit
      # This links the contractor to the event of the payment they are supposed to see.
      create(:event_exhibition_contractor, exhibition_contractor_profile: exhibition_contractor_user.reload.exhibition_contractor_profile, event: payment_contractor.exhibitor_kit.event_vendor.event)
      expect(Pundit.policy_scope!(exhibition_contractor_user, ExhibitorKitPayment).to_a).to match_array([payment_contractor])
    end

    it 'Exhibitor sees their own payments' do
      isolated_exhibitor_user = create(:user, :vendor)
      isolated_event = create(:event, user: create(:user, :organizer))
      isolated_exhibitor = create(:exhibitor, event: isolated_event, vendor: isolated_exhibitor_user)
      isolated_exhibitor_kit = create(:exhibitor_kit, event_vendor: isolated_exhibitor)
      isolated_payment_for_exhibitor = create(:exhibitor_kit_payment, exhibitor_kit: isolated_exhibitor_kit, payee: isolated_event.staff.first)
      expect(Pundit.policy_scope!(isolated_exhibitor_user, ExhibitorKitPayment).to_a).to match_array([isolated_payment_for_exhibitor])
    end

    it 'Other users see no payments' do
      expect(Pundit.policy_scope!(other_user, ExhibitorKitPayment).to_a).to be_empty
    end
  end
end