require 'rails_helper'

RSpec.describe GroupAffiliate, type: :model do
  describe 'associations' do
    it { should belong_to(:group) }
    it { should belong_to(:vendor).class_name('User') }
  end

  describe 'validations' do
    let(:group) { create(:group) }
    let(:vendor) { create(:vendor_user) }
    let(:manager) { create(:organizer_user) }
    subject { build(:group_affiliate, group: group, vendor: vendor) }

    it { should validate_uniqueness_of(:vendor_id).scoped_to(:group_id).with_message('is already asssigned to this group') }

    it 'validates that vendor must have vendor role' do
      affiliate = build(:group_affiliate, group: group, vendor: manager)
      expect(affiliate).not_to be_valid
      expect(affiliate.errors[:vendor]).to include('must have vendor role')
    end

    it 'allows vendor users' do
      affiliate = build(:group_affiliate, group: group, vendor: vendor)
      expect(affiliate).to be_valid
    end
  end

end
