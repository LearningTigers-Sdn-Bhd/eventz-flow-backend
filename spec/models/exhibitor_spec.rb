# spec/models/exhibitor_spec.rb

require 'rails_helper'

RSpec.describe Exhibitor, type: :model do
  describe 'associations' do
    it { should belong_to(:exhibitor_owner).class_name('ExhibitorOwner').optional }
    it { should belong_to(:event) }
    it { should belong_to(:vendor).class_name('User') }
  end

  describe 'validations' do
    # exhibitor_owner_id is optional - Exhibitors can be independent
    it { should_not validate_presence_of(:exhibitor_owner_id) }
    it { should validate_presence_of(:event_id) }
    it { should validate_presence_of(:vendor_id) }
    it { should validate_presence_of(:redirect_url) }
  end

  describe 'scopes' do
    let(:exhibitor_owner) { create(:exhibitor_owner) }
    let!(:exhibitor1) { create(:exhibitor, exhibitor_owner: exhibitor_owner) }
    let!(:exhibitor2) { create(:exhibitor, exhibitor_owner: exhibitor_owner) }
    let!(:independent_exhibitor) { create(:exhibitor, :independent) }

    it 'returns exhibitors owned by a specific owner' do
      owned = Exhibitor.owned_by(exhibitor_owner)
      expect(owned).to include(exhibitor1, exhibitor2)
      expect(owned).not_to include(independent_exhibitor)
    end

    it 'returns independent exhibitors with independent scope' do
      expect(Exhibitor.independent).to include(independent_exhibitor)
      expect(Exhibitor.independent).not_to include(exhibitor1, exhibitor2)
    end

    it 'returns owned exhibitors with owned scope' do
      expect(Exhibitor.owned).to include(exhibitor1, exhibitor2)
      expect(Exhibitor.owned).not_to include(independent_exhibitor)
    end
  end

  describe '#exhibitor_owner_name' do
    let(:exhibitor_owner) { create(:exhibitor_owner, name: 'Test Owner') }
    let(:exhibitor) { create(:exhibitor, exhibitor_owner: exhibitor_owner) }

    it 'returns the name of the exhibitor owner' do
      expect(exhibitor.exhibitor_owner_name).to eq('Test Owner')
    end

    context 'when exhibitor_owner is nil' do
      let(:exhibitor) { build(:exhibitor, exhibitor_owner: nil) }

      it 'returns nil' do
        expect(exhibitor.exhibitor_owner_name).to be_nil
      end
    end
  end

  describe '#can_manage_vendor?' do
    let(:exhibitor) { create(:exhibitor) }
    let(:user) { create(:user) }

    it 'returns false by default' do
      expect(exhibitor.can_manage_vendor?(user)).to be_falsey
    end
  end

  describe '#independent?' do
    context 'when exhibitor has no owner' do
      let(:exhibitor) { build(:exhibitor, exhibitor_owner: nil) }

      it 'returns true' do
        expect(exhibitor.independent?).to be_truthy
      end
    end

    context 'when exhibitor has an owner' do
      let(:exhibitor_owner) { create(:exhibitor_owner) }
      let(:exhibitor) { create(:exhibitor, exhibitor_owner: exhibitor_owner) }

      it 'returns false' do
        expect(exhibitor.independent?).to be_falsey
      end
    end
  end

  describe '#owned?' do
    context 'when exhibitor has an owner' do
      let(:exhibitor_owner) { create(:exhibitor_owner) }
      let(:exhibitor) { create(:exhibitor, exhibitor_owner: exhibitor_owner) }

      it 'returns true' do
        expect(exhibitor.owned?).to be_truthy
      end
    end

    context 'when exhibitor has no owner' do
      let(:exhibitor) { build(:exhibitor, exhibitor_owner: nil) }

      it 'returns false' do
        expect(exhibitor.owned?).to be_falsey
      end
    end
  end
end
