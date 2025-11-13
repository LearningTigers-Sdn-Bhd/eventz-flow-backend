# spec/models/exhibitor_owner_spec.rb

require 'rails_helper'

RSpec.describe ExhibitorOwner, type: :model do
  describe 'associations' do
    it { should have_many(:exhibitors).class_name('Exhibitor').with_foreign_key('exhibitor_owner_id') }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }

    context 'when contact_email is provided' do
      it 'validates email format' do
        owner = build(:exhibitor_owner, contact_email: 'invalid-email')
        expect(owner).not_to be_valid
        expect(owner.errors[:contact_email]).to be_present
      end

      it 'accepts valid email format' do
        owner = build(:exhibitor_owner, contact_email: 'valid@example.com')
        expect(owner).to be_valid
      end
    end

    context 'when contact_email is blank' do
      it 'allows blank email' do
        owner = build(:exhibitor_owner, contact_email: '')
        expect(owner).to be_valid
      end
    end
  end

  describe 'dependent: :restrict_with_error' do
    let(:exhibitor_owner) { create(:exhibitor_owner) }
    let(:event) { create(:event, use_ticket: true) }
    let(:vendor) { create(:vendor_user) }

    it 'prevents deletion when exhibitors exist' do
      create(:exhibitor, exhibitor_owner: exhibitor_owner, event: event, vendor: vendor)

      expect(exhibitor_owner.destroy).to be_falsey
      expect(exhibitor_owner.errors[:base]).to include('Cannot delete record because dependent exhibitors exist')
      expect(ExhibitorOwner.exists?(exhibitor_owner.id)).to be_truthy
    end

    it 'allows deletion when no exhibitors exist' do
      expect { exhibitor_owner.destroy }.not_to raise_error
      expect(ExhibitorOwner.exists?(exhibitor_owner.id)).to be_falsey
    end
  end

  describe 'optional fields' do
    it 'allows description to be blank' do
      owner = build(:exhibitor_owner, description: nil)
      expect(owner).to be_valid
    end

    it 'allows contact_phone to be blank' do
      owner = build(:exhibitor_owner, contact_phone: nil)
      expect(owner).to be_valid
    end
  end
end
