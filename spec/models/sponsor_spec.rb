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

  describe 'Analytics' do
    let(:sponsor) { create(:sponsor) }
    let(:event1) { create(:event) }
    let(:event2) { create(:event) }

    before do
      s1 = create(:event_sponsorship, sponsor: sponsor, event: event1, total_sponsor_amount: 1000)
      s2 = create(:event_sponsorship, sponsor: sponsor, event: event2, total_sponsor_amount: 2000)
      
      create(:event_sponsorship_payment, event_sponsorship: s1, amount: 500)
      create(:event_sponsorship_item, event_sponsorship: s2, total_value: 1000, received: true)
    end

    it 'calculates total_sponsorship_count' do
      expect(sponsor.total_sponsorship_count).to eq(2)
    end

    it 'calculates total_pledged_amount' do
      expect(sponsor.total_pledged_amount).to eq(3000)
    end

    it 'calculates total_received_amount' do
      expect(sponsor.total_received_amount).to eq(1500)
    end
  end
end
