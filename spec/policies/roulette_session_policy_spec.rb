require 'rails_helper'

RSpec.describe RouletteSessionPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:exhibitor) { create(:user, :exhibitor) }
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }

  let(:session_owned) { create(:roulette_session, user: owner) }

  permissions :show? do
    it 'allows org_owner' do
      expect(policy).to permit(org_owner, session_owned)
    end

    it 'allows organizer' do
      expect(policy).to permit(organizer, session_owned)
    end

    it 'allows exhibitor' do
      expect(policy).to permit(exhibitor, session_owned)
    end

    it 'allows owner' do
      expect(policy).to permit(owner, session_owned)
    end

    it 'allows assigned user' do
      assigned = create(:user)
      create(:roulette_assign, roulette_session: session_owned, user: assigned)
      expect(policy).to permit(assigned, session_owned)
    end

    it 'denies unrelated user' do
      expect(policy).not_to permit(other_user, session_owned)
    end
  end

  permissions :create? do
    it 'allows any authenticated user' do
      expect(policy).to permit(owner, RouletteSession.new)
    end
  end

  permissions :update?, :destroy?, :background_manager? do
    it 'allows org_owner' do
      expect(policy).to permit(org_owner, session_owned)
    end

    it 'allows organizer' do
      expect(policy).to permit(organizer, session_owned)
    end

    it 'allows owner' do
      expect(policy).to permit(owner, session_owned)
    end

    it 'denies exhibitor who is not owner' do
      expect(policy).not_to permit(exhibitor, session_owned)
    end
  end

  describe 'Scope' do
    let!(:session1) { create(:roulette_session, user: owner) }
    let!(:session2) { create(:roulette_session, user: other_user) }
    let!(:assigned_session) do
      s = create(:roulette_session, user: other_user)
      create(:roulette_assign, roulette_session: s, user: exhibitor)
      s
    end

    it 'returns all sessions for org_owner' do
      scope = described_class::Scope.new(org_owner, RouletteSession.all).resolve
      expect(scope).to include(session1, session2, assigned_session)
    end

    it 'returns owned and assigned sessions for exhibitor' do
      owned = create(:roulette_session, user: exhibitor)
      scope = described_class::Scope.new(exhibitor, RouletteSession.all).resolve
      expect(scope).to include(owned, assigned_session)
      expect(scope).not_to include(session1, session2)
    end
  end
end
