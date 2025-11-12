require 'rails_helper'

RSpec.describe GroupAffiliate, type: :model do
  describe 'associations' do
    it { should belong_to(:group) }
    it { should belong_to(:vendor).class_name('User') }
  end

  describe 'validations' do
    let(:group) { create(:group) }
    let(:vendor) { create(:vendor_user) }
    let(:manager) { create(:manager_user) }
    subject { build(:group_affiliate, group: group, vendor: vendor) }

    it { should validate_uniqueness_of(:group_id) }

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

  describe 'callbacks' do
    let(:group) { create(:group) }
    let(:vendor) { create(:vendor_user) }

    it 'creates vendor profile when group affiliate is created' do
      expect {
        create(:group_affiliate, group: group, vendor: vendor)
      }.to change { VendorProfile.count }.by(1)

      vendor_profile = VendorProfile.find_by(group: group, vendor: vendor)
      expect(vendor_profile).to be_present
      expect(vendor_profile.vendor_name).to eq('Vendor Name')
    end

    it 'does not create duplicate vendor profile if one already exists' do
      create(:vendor_profile, group: group, vendor: vendor)

      expect {
        create(:group_affiliate, group: group, vendor: vendor)
      }.not_to change { VendorProfile.count }

      expect(VendorProfile.where(group: group, vendor: vendor).count).to eq(1)
    end

    it 'sets manager_id from existing vendor profiles if available' do
      manager = create(:manager_user)
      other_group = create(:group)
      existing_profile = create(:vendor_profile, group: other_group, vendor: vendor, manager_id: manager.id)

      expect {
        create(:group_affiliate, group: group, vendor: vendor)
      }.to change { VendorProfile.count }.by(1)

      new_profile = VendorProfile.find_by(group: group, vendor: vendor)
      expect(new_profile.manager_id).to eq(manager.id)
    end
  end
end
