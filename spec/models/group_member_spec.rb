require 'rails_helper'

RSpec.describe GroupMember, type: :model do
  describe 'associations' do
    it { should belong_to(:group) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    let(:group) { create(:group) }
    let(:manager) { create(:manager_user) }
    let(:member) { create(:member_user) }
    let(:org_owner) { create(:org_owner) }
    subject { build(:group_member, group: group, user: manager) }

    it { should validate_uniqueness_of(:user_id).scoped_to(:group_id) }

    it 'validates that user cannot be org_owner' do
      group_member = build(:group_member, group: group, user: org_owner)
      expect(group_member).not_to be_valid
      expect(group_member.errors[:user]).to include('cannot be an org_owner')
    end

    it 'allows manager users' do
      group_member = build(:group_member, group: group, user: manager)
      expect(group_member).to be_valid
    end

    it 'allows member users' do
      group_member = build(:group_member, group: group, user: member)
      expect(group_member).to be_valid
    end

    it 'rejects vendor users' do
      vendor = create(:vendor_user)
      group_member = build(:group_member, group: group, user: vendor)
      expect(group_member).not_to be_valid
      expect(group_member.errors[:user]).to include('must be a manager or member')
    end
  end

  describe 'methods' do
    let(:group) { create(:group) }
    let(:manager) { create(:manager_user) }
    let(:member) { create(:member_user) }

    describe '#manager?' do
      it 'returns true when has_manager_access is true' do
        group_member = create(:group_member, group: group, user: manager, has_manager_access: true)
        expect(group_member.manager?).to be true
      end

      it 'returns false when has_manager_access is false' do
        group_member = create(:group_member, group: group, user: member, has_manager_access: false)
        expect(group_member.manager?).to be false
      end
    end
  end
end
