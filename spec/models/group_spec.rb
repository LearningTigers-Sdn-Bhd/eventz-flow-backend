require 'rails_helper'

RSpec.describe Group, type: :model do
  describe 'associations' do
    it { should have_many(:group_members).dependent(:destroy) }
    it { should have_many(:users).through(:group_members) }
    it { should have_one(:group_affiliate).dependent(:destroy) }
    it { should have_one(:vendor).through(:group_affiliate) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'scopes' do
    let(:org_owner) { create(:org_owner) }
    let(:manager) { create(:manager_user) }
    let(:member) { create(:member_user) }
    let(:vendor) { create(:vendor_user) }
    let(:group1) { create(:group) }
    let(:group2) { create(:group) }
    let(:group3) { create(:group) }

    describe '.with_vendor' do
      it 'returns groups with vendors' do
        create(:group_affiliate, group: group1, vendor: vendor)
        create(:group, name: 'No Vendor Group')

        expect(Group.with_vendor).to include(group1)
        expect(Group.with_vendor.count).to eq(1)
      end
    end

    describe '.managed_by' do
      it 'returns groups managed by a user' do
        create(:group_member, group: group1, user: manager, has_manager_access: true)
        create(:group_member, group: group2, user: member, has_manager_access: false)

        expect(Group.managed_by(manager)).to include(group1)
        expect(Group.managed_by(manager)).not_to include(group2)
      end
    end

    describe '.visible_to' do
      it 'returns all groups for org_owner' do
        expect(Group.visible_to(org_owner)).to eq(Group.all)
      end

      it 'returns groups assigned to vendor' do
        create(:group_affiliate, group: group1, vendor: vendor)

        expect(Group.visible_to(vendor)).to include(group1)
        expect(Group.visible_to(vendor)).not_to include(group2)
      end

      it 'returns groups where user is a member' do
        create(:group_member, group: group1, user: manager)
        create(:group_member, group: group2, user: member)

        expect(Group.visible_to(manager)).to include(group1)
        expect(Group.visible_to(member)).to include(group2)
      end
    end
  end
end
