require 'rails_helper'

RSpec.describe RouletteWinner, type: :model do
  describe 'associations' do
    it { should belong_to(:roulette_session) }
    it { should belong_to(:roulette_prize) }
    it { should belong_to(:ticket).optional }
    it { should belong_to(:visitor).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:roulette_session_id) }
    it { should validate_presence_of(:roulette_prize_id) }
    it { should validate_presence_of(:drawn_at) }

    it 'requires exactly one of ticket or visitor' do
      session = create(:roulette_session)
      prize = create(:roulette_prize, roulette_session: session)

      winner = build(:roulette_winner, roulette_session: session, roulette_prize: prize, ticket: nil, visitor: nil)
      expect(winner).not_to be_valid
      expect(winner.errors[:base]).to include('Either ticket_id or visitor_id must be present')

      ticket = create(:ticket)
      visitor = create(:visitor)
      winner = build(:roulette_winner, roulette_session: session, roulette_prize: prize, ticket: ticket, visitor: visitor)
      expect(winner).not_to be_valid
      expect(winner.errors[:base]).to include('Cannot have both ticket_id and visitor_id')
    end
  end
end
