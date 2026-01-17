require 'rails_helper'

RSpec.describe RoulettePrize, type: :model do
  describe 'associations' do
    it { should belong_to(:roulette_session) }
    it { should have_many(:roulette_winners).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:roulette_session_id) }
    it { should validate_presence_of(:name) }

    it 'validates quantity is >= 0' do
      prize = build(:roulette_prize, quantity: -1)
      expect(prize).not_to be_valid
      expect(prize.errors[:quantity]).to be_present
    end
  end

  describe '#remaining_quantity and #has_winner?' do
    let(:prize) { create(:roulette_prize, quantity: 3) }

    it 'calculates remaining quantity with no winners' do
      expect(prize.remaining_quantity).to eq(3)
      expect(prize.has_winner?).to be_falsey
    end

    it 'updates remaining quantity when winners are added' do
      create(:roulette_winner, :with_ticket, roulette_prize: prize, roulette_session: prize.roulette_session)
      create(:roulette_winner, :with_visitor, roulette_prize: prize, roulette_session: prize.roulette_session)

      expect(prize.remaining_quantity).to eq(1)
      expect(prize.has_winner?).to be_truthy
    end
  end
end
