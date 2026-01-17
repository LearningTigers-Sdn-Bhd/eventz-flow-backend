require 'rails_helper'

RSpec.describe RouletteWinnerPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:exhibitor) { create(:user, :exhibitor) }
  let(:owner) { create(:user) }
  let(:assigned_user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:session) { create(:roulette_session, user: owner) }
  let(:prize) { create(:roulette_prize, roulette_session: session) }
  let(:winner) { build(:roulette_winner, :with_ticket, roulette_session: session, roulette_prize: prize) }

  permissions :create? do
    it 'allows org_owner' do
      expect(policy).to permit(org_owner, winner)
    end

    it 'allows organizer' do
      expect(policy).to permit(organizer, winner)
    end

    it 'allows session owner' do
      expect(policy).to permit(owner, winner)
    end

    it 'allows assigned user (including exhibitor)' do
      create(:roulette_assign, roulette_session: session, user: assigned_user)
      expect(policy).to permit(assigned_user, winner)
    end

    it 'denies unrelated user' do
      expect(policy).not_to permit(other_user, winner)
    end
  end
end
