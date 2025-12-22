require 'rails_helper'

RSpec.describe ExhibitorKitPayment, type: :model do
  describe 'associations' do
    it { should belong_to(:exhibitor_kit) }
    it { should belong_to(:payee).class_name('User') }
    it { should have_many(:exhibitor_kit_items) }
    it { should have_many(:exhibitor_kit_printings) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, submitted: 1, verified: 2, rejected: 3) }
    it { should define_enum_for(:payment_source).backed_by_column_of_type(:string).with_values(manual_bank_in: 'manual_bank_in', payment_gateway: 'payment_gateway') }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:status) }

    context 'when status is submitted' do
      subject { FactoryBot.build(:exhibitor_kit_payment, status: :submitted, payment_source: :manual_bank_in) }
      it { should validate_presence_of(:payment_source) }
      it 'validates presence of payment_proof' do
        subject.payment_proof.detach
        expect(subject).not_to be_valid
        expect(subject.errors[:payment_proof]).to include("can't be blank")
      end
    end

    context 'when payment_source is payment_gateway' do
      subject { FactoryBot.build(:exhibitor_kit_payment, payment_source: :payment_gateway) }
      it { should validate_presence_of(:external_ref) }
    end
  end
end
