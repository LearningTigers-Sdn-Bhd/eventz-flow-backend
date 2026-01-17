require 'rails_helper'

RSpec.describe UserSession, type: :model do
  describe 'Associations' do
    it { should belong_to(:user) }
  end

  describe 'Validations' do
    subject { create(:user_session) }
    it { should validate_presence_of(:jti) }
    it { should validate_uniqueness_of(:jti) }
    it { should validate_presence_of(:refresh_token_hash) }
    it { should validate_uniqueness_of(:refresh_token_hash) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'Scopes' do
    let!(:active_session) { create(:user_session) }
    let!(:revoked_session) { create(:user_session, :revoked) }
    let!(:expired_session) { create(:user_session, :expired) }

    describe '.active' do
      it 'returns only non-revoked and non-expired sessions' do
        expect(described_class.active).to include(active_session)
        expect(described_class.active).not_to include(revoked_session)
        expect(described_class.active).not_to include(expired_session)
      end
    end

    describe '.expired' do
      it 'returns only expired sessions' do
        expect(described_class.expired).to include(expired_session)
        expect(described_class.expired).not_to include(active_session)
      end
    end
  end

  describe 'Methods' do
    let(:session) { create(:user_session) }

    describe '#active?' do
      it 'returns true for active session' do
        expect(session.active?).to be true
      end

      it 'returns false for revoked session' do
        session.update!(revoked: true)
        expect(session.active?).to be false
      end

      it 'returns false for expired session' do
        session.update!(expires_at: 1.hour.ago)
        expect(session.active?).to be false
      end
    end

    describe '#revoke!' do
      it 'marks the session as revoked' do
        expect { session.revoke! }.to change { session.revoked }.from(false).to(true)
      end
    end

    describe '#touch!' do
      it 'updates last_used_at timestamp' do
        original_time = session.last_used_at
        travel 1.hour do
            session.touch!
            expect(session.last_used_at).to be > original_time
        end
      end
    end
  end
end
