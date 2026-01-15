require 'rails_helper'

RSpec.describe RouletteAssign, type: :model do
  describe 'associations' do
    it { should belong_to(:roulette_session) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:roulette_session_id) }
    it { should validate_presence_of(:user_id) }

    it 'validates uniqueness of user scoped to roulette_session' do
      session = create(:roulette_session)
      user = create(:user)

      create(:roulette_assign, roulette_session: session, user: user)
      duplicate = build(:roulette_assign, roulette_session: session, user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('is already assigned to this session')
    end
  end
end
