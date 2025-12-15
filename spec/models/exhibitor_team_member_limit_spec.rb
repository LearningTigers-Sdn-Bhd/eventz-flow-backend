require 'rails_helper'

RSpec.describe ExhibitorTeamMemberLimit, type: :model do
  let(:event) { create(:event) }

  describe 'associations' do
    it { should belong_to(:event) }
  end

  describe 'validations' do
    subject { build(:exhibitor_team_member_limit, event: event) }

    it { should validate_uniqueness_of(:event_id) }
    it { should validate_numericality_of(:team_member_limit).only_integer.is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:extra_team_member_fee).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe '#has_limit?' do
    it 'returns true when team_member_limit is set and greater than 0' do
      limit = build(:exhibitor_team_member_limit, team_member_limit: 3)
      expect(limit.has_limit?).to be true
    end

    it 'returns false when team_member_limit is nil' do
      limit = build(:exhibitor_team_member_limit, team_member_limit: nil)
      expect(limit.has_limit?).to be false
    end

    it 'returns false when team_member_limit is 0' do
      limit = build(:exhibitor_team_member_limit, team_member_limit: 0)
      expect(limit.has_limit?).to be false
    end
  end

  describe '#charges_extra_fee?' do
    it 'returns true when extra_team_member_fee is greater than 0' do
      limit = build(:exhibitor_team_member_limit, extra_team_member_fee: 50.00)
      expect(limit.charges_extra_fee?).to be true
    end

    it 'returns false when extra_team_member_fee is 0' do
      limit = build(:exhibitor_team_member_limit, extra_team_member_fee: 0)
      expect(limit.charges_extra_fee?).to be false
    end

    it 'returns false when extra_team_member_fee is nil' do
      limit = build(:exhibitor_team_member_limit, extra_team_member_fee: nil)
      expect(limit.charges_extra_fee?).to be false
    end
  end
end

