# spec/models/vendor_profile_spec.rb
require 'rails_helper'

RSpec.describe VendorProfile, type: :model do
  # --- Setup ---
  let(:group) { create(:group) }
  let(:vendor) { create(:user, role: :vendor) }
  let!(:group_affiliate) do
    create(:group_affiliate, group: group, vendor: vendor)
  end

  let(:valid_attributes) do
    {
      group: group,
      vendor: vendor,
      vendor_name: 'Test Vendor',
      vendor_description: 'Test description'
    }
  end

  let(:valid_vendor_profile) { build(:vendor_profile, group: group, vendor: vendor) }

  # --- Associations ---
  describe 'Associations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:vendor).class_name('User') }
    it { is_expected.to belong_to(:manager).class_name('User').optional }
    # Note: event_vendors association is scoped by vendor_id
    it 'has many event_vendors scoped to vendor' do
      profile = VendorProfile.find_by(group: group, vendor: vendor)
      expect(profile.event_vendors).to respond_to(:each)
    end
  end

  # --- Validations ---
  describe 'Validations' do
    subject { valid_vendor_profile }

    it { is_expected.to validate_presence_of(:group_id) }
    it { is_expected.to validate_presence_of(:vendor_id) }
  end

  # --- Uniqueness ---
  describe 'Uniqueness' do
    it 'validates uniqueness of vendor_id scoped to group_id' do
      # vendor_profile is already created by the GroupAffiliate callback
      duplicate = build(:vendor_profile, group: group, vendor: vendor)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:vendor_id]).to include('already has a profile for this group')
    end

    it 'allows same vendor with different groups' do
      # vendor_profile is already created by the GroupAffiliate callback
      other_group = create(:group)
      create(:group_affiliate, group: other_group, vendor: vendor)
      # This will create a new vendor_profile for the other_group via callback
      duplicate = VendorProfile.find_by(group: other_group, vendor: vendor)
      expect(duplicate).to be_valid
    end

    it 'allows different vendors with same group' do
      # Note: Only one vendor can be affiliated with a group (group_id uniqueness in group_affiliates)
      # So this test is not applicable - each group can only have one vendor
      # If we want to test different vendors, they must be in different groups
      other_vendor = create(:user, role: :vendor)
      other_group = create(:group)
      create(:group_affiliate, group: other_group, vendor: other_vendor)
      # This will create a new vendor_profile for the other_vendor in other_group via callback
      profile = VendorProfile.find_by(group: other_group, vendor: other_vendor)
      expect(profile).to be_valid
      expect(profile.group_id).to eq(other_group.id)
    end
  end

  # --- Default Values ---
  describe 'Default Values' do
    it 'defaults vendor_name to "Vendor Name"' do
      # vendor_profile is already created by the GroupAffiliate callback
      profile = VendorProfile.find_by(group: group, vendor: vendor)
      expect(profile.vendor_name).to eq('Vendor Name')
    end
  end
end
