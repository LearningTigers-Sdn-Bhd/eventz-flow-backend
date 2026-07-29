require 'rails_helper'

RSpec.describe PublicExhibitorAccessSession, type: :model do
  let(:event) { create(:event) }

  it 'stores only digests and consumes a challenge once' do
    access, challenge = described_class.issue_challenge!(event: event, email: ' Vendor@Example.com ')

    expect(access.normalized_email).to eq('vendor@example.com')
    expect(access.challenge_digest).to eq(Digest::SHA256.hexdigest(challenge))
    expect(access.attributes.values).not_to include(challenge)
    expect(access.exchange_challenge!(challenge)).to be_present
    expect { access.reload.exchange_challenge!(challenge) }.to raise_error(described_class::InvalidToken)
  end

  it 'rejects expired and revoked sessions' do
    access, challenge = described_class.issue_challenge!(event: event, email: 'vendor@example.com')
    token = access.exchange_challenge!(challenge)
    access.update!(expires_at: 1.minute.ago)
    expect(described_class.authenticate(event: event, token: token)).to be_nil

    access.update!(expires_at: 1.hour.from_now, revoked_at: Time.current)
    expect(described_class.authenticate(event: event, token: token)).to be_nil
  end
end
