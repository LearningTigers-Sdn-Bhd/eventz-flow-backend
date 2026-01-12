require 'rails_helper'

RSpec.describe EventSponsorship, type: :model do
  describe 'Associations' do
    it { should belong_to(:group) }
    it { should belong_to(:event) }
    it { should belong_to(:sponsor) }
    it { should belong_to(:event_sponsorship_tier).optional }
    it { should belong_to(:internal_owner_user).class_name('User').optional }
    it { should have_many(:event_sponsorship_payments).dependent(:destroy) }
    it { should have_many(:event_sponsorship_attachments).dependent(:destroy) }
    it { should have_many(:event_sponsorship_items).dependent(:destroy) }
  end

  describe 'Validations' do
    it { should validate_presence_of(:title) }
    it { should validate_numericality_of(:total_sponsor_amount).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe 'Enums' do
    it { should define_enum_for(:sponsorship_type).with_values(monetary: 0, in_kind: 1, mixed: 2) }
    it { should define_enum_for(:status).with_values(pending: 0, partially_received: 1, received: 2, cancelled: 3) }
  end

  describe 'Logic' do
    let(:sponsorship) { create(:event_sponsorship, total_sponsor_amount: 1000) }

    context 'payment aggregation' do
      it 'updates totals and status to partially_received' do
        create(:event_sponsorship_payment, event_sponsorship: sponsorship, amount: 500)
        sponsorship.reload
        expect(sponsorship.received_total).to eq(500)
        expect(sponsorship.status).to eq('partially_received')
      end

      it 'updates totals and status to received' do
        create(:event_sponsorship_payment, event_sponsorship: sponsorship, amount: 1000)
        sponsorship.reload
        expect(sponsorship.received_total).to eq(1000)
        expect(sponsorship.status).to eq('received')
      end
    end

    context 'snapshots' do
      let(:tier) { create(:event_sponsorship_tier, name: "Gold") }
      let(:sponsor) { create(:sponsor, default_contact_name: "Original Contact") }

      it 'snapshots tier name' do
        sponsorship = create(:event_sponsorship, event_sponsorship_tier: tier)
        expect(sponsorship.tier_name_snapshot).to eq("Gold")
      end

      it 'snapshots contact info' do
        sponsorship = create(:event_sponsorship, sponsor: sponsor, contact_name: nil)
        expect(sponsorship.contact_name).to eq("Original Contact")
      end
    end
  end
end
