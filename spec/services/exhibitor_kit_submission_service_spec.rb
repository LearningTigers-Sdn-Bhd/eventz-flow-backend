require 'rails_helper'

RSpec.describe ExhibitorKitSubmissionService, type: :service do
  let(:org_owner) { create(:user, :org_owner) }
  let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
  let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }
  let(:event) { create(:event, allow_contractor_printing_services: true) }
  let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
  let(:exhibitor) { create(:exhibitor, event: event) }
  let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

  subject(:service) { described_class.new(user: exhibitor.vendor, exhibitor_kit: exhibitor_kit) }

  describe '#call' do
    context 'when there are no unpaid items' do
      it 'returns an error' do
        result = service.call
        expect(result).not_to be_success
        expect(result.errors).to eq("No unpaid items or printings to submit")
      end
    end

    context 'when all items belong to contractor' do
      let!(:rentable_item1) { create(:rentable_item, user: contractor_user) }
      let!(:rentable_item2) { create(:rentable_item, user: contractor_user) }
      let!(:event_rentable_item1) { create(:event_rentable_item, event: event, rentable_item: rentable_item1) }
      let!(:event_rentable_item2) { create(:event_rentable_item, event: event, rentable_item: rentable_item2) }
      let!(:kit_item1) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item1, quantity: 2, agreed_price: 100) }
      let!(:kit_item2) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item2, quantity: 1, agreed_price: 50) }

      it 'creates one payment' do
        expect { service.call }.to change(ExhibitorKitPayment, :count).by(1)
      end

      it 'returns success with array of payments' do
        result = service.call
        expect(result).to be_success
        expect(result.data).to be_an(Array)
        expect(result.data.length).to eq(1)
      end

      it 'sets the correct payee' do
        result = service.call
        payment = result.data.first
        expect(payment.payee_id).to eq(contractor_user.id)
      end

      it 'calculates the correct total' do
        result = service.call
        payment = result.data.first
        expect(payment.amount).to eq(250) # (2 * 100) + (1 * 50)
      end

      it 'links items to the payment' do
        result = service.call
        payment = result.data.first
        expect(kit_item1.reload.exhibitor_kit_payment_id).to eq(payment.id)
        expect(kit_item2.reload.exhibitor_kit_payment_id).to eq(payment.id)
      end
    end

    context 'when items belong to different owners (mixed ownership)' do
      let!(:rentable_item_contractor) { create(:rentable_item, user: contractor_user) }
      let!(:rentable_item_org) { create(:rentable_item, user: org_owner) }
      let!(:event_rentable_item1) { create(:event_rentable_item, event: event, rentable_item: rentable_item_contractor) }
      let!(:event_rentable_item2) { create(:event_rentable_item, event: event, rentable_item: rentable_item_org) }
      let!(:kit_item_contractor) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item_contractor, quantity: 1, agreed_price: 100) }
      let!(:kit_item_org) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item_org, quantity: 2, agreed_price: 75) }

      it 'creates two payments (one per owner)' do
        expect { service.call }.to change(ExhibitorKitPayment, :count).by(2)
      end

      it 'returns success with array of two payments' do
        result = service.call
        expect(result).to be_success
        expect(result.data).to be_an(Array)
        expect(result.data.length).to eq(2)
      end

      it 'sets correct payee for each payment' do
        result = service.call
        payee_ids = result.data.map(&:payee_id)
        expect(payee_ids).to contain_exactly(contractor_user.id, org_owner.id)
      end

      it 'calculates correct totals for each payment' do
        result = service.call
        contractor_payment = result.data.find { |p| p.payee_id == contractor_user.id }
        org_payment = result.data.find { |p| p.payee_id == org_owner.id }

        expect(contractor_payment.amount).to eq(100) # 1 * 100
        expect(org_payment.amount).to eq(150) # 2 * 75
      end

      it 'links items to correct payments' do
        result = service.call
        contractor_payment = result.data.find { |p| p.payee_id == contractor_user.id }
        org_payment = result.data.find { |p| p.payee_id == org_owner.id }

        expect(kit_item_contractor.reload.exhibitor_kit_payment_id).to eq(contractor_payment.id)
        expect(kit_item_org.reload.exhibitor_kit_payment_id).to eq(org_payment.id)
      end
    end

    context 'when items and printing services belong to same owner' do
      let!(:rentable_item) { create(:rentable_item, user: contractor_user) }
      let!(:printing_service) { create(:printing_service, user: contractor_user) }
      let!(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }
      let!(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }
      let!(:kit_item) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item, quantity: 1, agreed_price: 100) }
      let!(:kit_printing) { create(:exhibitor_kit_printing, exhibitor_kit: exhibitor_kit, printing_service: printing_service, quantity: 2, agreed_price: 50) }

      it 'creates one payment combining items and services' do
        expect { service.call }.to change(ExhibitorKitPayment, :count).by(1)
      end

      it 'calculates total including both items and services' do
        result = service.call
        payment = result.data.first
        expect(payment.amount).to eq(200) # (1 * 100) + (2 * 50)
      end

      it 'links both item and printing to the payment' do
        result = service.call
        payment = result.data.first
        expect(kit_item.reload.exhibitor_kit_payment_id).to eq(payment.id)
        expect(kit_printing.reload.exhibitor_kit_payment_id).to eq(payment.id)
      end
    end

    context 'when items and printing services belong to different owners' do
      let!(:rentable_item) { create(:rentable_item, user: contractor_user) }
      let!(:printing_service) { create(:printing_service, user: org_owner) }
      let!(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }
      let!(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }
      let!(:kit_item) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item, quantity: 1, agreed_price: 100) }
      let!(:kit_printing) { create(:exhibitor_kit_printing, exhibitor_kit: exhibitor_kit, printing_service: printing_service, quantity: 2, agreed_price: 50) }

      it 'creates two payments (one per owner)' do
        expect { service.call }.to change(ExhibitorKitPayment, :count).by(2)
      end

      it 'separates item and printing into different payments' do
        result = service.call
        contractor_payment = result.data.find { |p| p.payee_id == contractor_user.id }
        org_payment = result.data.find { |p| p.payee_id == org_owner.id }

        expect(contractor_payment.amount).to eq(100) # item only
        expect(org_payment.amount).to eq(100) # printing only (2 * 50)
      end
    end

    context 'when only org_owner items exist (no contractor items)' do
      let!(:rentable_item) { create(:rentable_item, user: org_owner) }
      let!(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }
      let!(:kit_item) { create(:exhibitor_kit_item, exhibitor_kit: exhibitor_kit, rentable_item: rentable_item, quantity: 1, agreed_price: 100) }

      it 'creates payment for org_owner' do
        result = service.call
        expect(result).to be_success
        expect(result.data.first.payee_id).to eq(org_owner.id)
      end
    end
  end
end
