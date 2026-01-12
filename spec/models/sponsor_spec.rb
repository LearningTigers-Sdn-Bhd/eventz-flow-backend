require 'rails_helper'

RSpec.describe Sponsor, type: :model do
  describe 'Associations' do
    it { should belong_to(:group) }
    it { should belong_to(:created_by).class_name('User').optional }
    it { should have_many(:event_sponsorships).dependent(:destroy) }
    it { should have_many(:events).through(:event_sponsorships) }
  end

  describe 'Validations' do
    subject { create(:sponsor) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:group_id).case_insensitive }
  end

  describe 'Soft Delete' do
    let!(:sponsor) { create(:sponsor) }

    it 'soft deletes' do
      sponsor.soft_delete
      expect(sponsor.reload.deleted_at).to be_present
      expect(Sponsor.all).not_to include(sponsor)
      expect(Sponsor.only_deleted).to include(sponsor)
    end

    it 'restores' do
      sponsor.soft_delete
      sponsor.restore
      expect(sponsor.reload.deleted_at).to be_nil
      expect(Sponsor.all).to include(sponsor)
    end
  end
end
