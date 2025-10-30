require 'rails_helper'

RSpec.describe PasswordReset, type: :model do
  let!(:user) { create(:user) }

  describe '.issue_for!' do
    it 'creates a password reset and returns raw token' do
      token = nil
      expect { token = described_class.issue_for!(user) }
        .to change(described_class, :count).by(1)

      record = described_class.last
      expect(token).to be_present
      expect(record.user_id).to eq(user.id)
      expect(record.token_digest).to be_present
      expect(record.expires_at).to be > Time.current
    end
  end

  describe '#usable?' do
    it 'is true when not expired and not revoked' do
      described_class.issue_for!(user)
      record = described_class.last
      expect(record.usable?).to be true
    end

    it 'is false when expired' do
      described_class.issue_for!(user)
      record = described_class.last
      record.update!(expires_at: 1.minute.ago)
      expect(record.usable?).to be false
    end

    it 'is false when revoked' do
      described_class.issue_for!(user)
      record = described_class.last
      record.update!(revoked_at: Time.current)
      expect(record.usable?).to be false
    end
  end

  describe '.find_valid_by_token' do
    it 'finds the record by raw token' do
      raw = described_class.issue_for!(user)
      found = described_class.find_valid_by_token(raw)
      expect(found).to be_present
      expect(found.user_id).to eq(user.id)
    end

    it 'returns nil for invalid token' do
      expect(described_class.find_valid_by_token('invalid')).to be_nil
    end
  end
end
