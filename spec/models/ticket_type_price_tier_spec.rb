require 'rails_helper'

RSpec.describe TicketTypePriceTier, type: :model do
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }

  describe 'associations' do
    it { should belong_to(:ticket_type) }
  end

  describe 'validations' do
    it { should validate_presence_of(:label) }
    it { should validate_presence_of(:price) }
    it { should validate_presence_of(:starts_at) }
    it { should validate_presence_of(:ends_at) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }

    context 'ends_at_after_starts_at' do
      it 'is invalid when ends_at is before starts_at' do
        tier = build(:ticket_type_price_tier,
          ticket_type: ticket_type,
          starts_at: 2.days.from_now,
          ends_at: 1.day.from_now
        )
        expect(tier).not_to be_valid
        expect(tier.errors[:ends_at]).to include("must be after starts_at")
      end

      it 'is valid when ends_at is after starts_at' do
        tier = build(:ticket_type_price_tier,
          ticket_type: ticket_type,
          starts_at: 1.day.from_now,
          ends_at: 2.days.from_now
        )
        expect(tier).to be_valid
      end
    end

    context 'no_overlapping_tiers' do
      let!(:existing_tier) do
        create(:ticket_type_price_tier,
          ticket_type: ticket_type,
          label: "Early Bird",
          starts_at: 10.days.from_now,
          ends_at: 20.days.from_now
        )
      end

      it 'is invalid when dates overlap with existing tier' do
        overlapping = build(:ticket_type_price_tier,
          ticket_type: ticket_type,
          label: "Overlap",
          starts_at: 15.days.from_now,
          ends_at: 25.days.from_now
        )
        expect(overlapping).not_to be_valid
        expect(overlapping.errors[:base].first).to include("overlaps")
      end

      it 'is valid when dates do not overlap' do
        non_overlapping = build(:ticket_type_price_tier,
          ticket_type: ticket_type,
          label: "Normal",
          starts_at: 21.days.from_now,
          ends_at: 30.days.from_now
        )
        expect(non_overlapping).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_tier) do
        create(:ticket_type_price_tier,
          ticket_type: ticket_type,
          starts_at: 1.day.ago,
          ends_at: 1.day.from_now
        )
      end

      let!(:future_tier) do
        create(:ticket_type_price_tier,
          ticket_type: ticket_type,
          starts_at: 10.days.from_now,
          ends_at: 20.days.from_now
        )
      end

      it 'returns only active tiers' do
        expect(TicketTypePriceTier.active).to include(active_tier)
        expect(TicketTypePriceTier.active).not_to include(future_tier)
      end
    end
  end

  describe '#active?' do
    it 'returns true when current time is within range' do
      tier = build(:ticket_type_price_tier,
        starts_at: 1.day.ago,
        ends_at: 1.day.from_now
      )
      expect(tier.active?).to be true
    end

    it 'returns false when current time is outside range' do
      tier = build(:ticket_type_price_tier,
        starts_at: 10.days.from_now,
        ends_at: 20.days.from_now
      )
      expect(tier.active?).to be false
    end
  end
end
