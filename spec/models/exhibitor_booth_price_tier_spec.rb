require 'rails_helper'

RSpec.describe ExhibitorBoothPriceTier, type: :model do
  describe 'associations' do
    it { should belong_to(:exhibitor_booth_price) }
  end

  describe 'validations' do
    subject(:price_tier) { create(:exhibitor_booth_price_tier) }

    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:start_date) }

    it 'rejects overlapping tiers for the same booth price' do
      booth_price = create(:exhibitor_booth_price)
      create(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Early Bird',
        start_date: Time.current,
        end_date: 3.days.from_now
      )

      overlapping_tier = build(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Promo',
        start_date: 1.day.from_now,
        end_date: 4.days.from_now
      )

      expect(overlapping_tier).not_to be_valid
      expect(overlapping_tier.errors[:base]).to include("Date range overlaps with 'Early Bird'")
    end

    it 'allows adjacent tiers for the same booth price' do
      booth_price = create(:exhibitor_booth_price)
      boundary_time = Time.current.change(usec: 0)

      create(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Early Bird',
        start_date: boundary_time,
        end_date: boundary_time + 1.day
      )

      next_tier = build(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Standard',
        start_date: boundary_time + 1.day,
        end_date: boundary_time + 2.days
      )

      expect(next_tier).to be_valid
    end
  end
end
