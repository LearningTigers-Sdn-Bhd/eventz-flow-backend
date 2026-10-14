require 'rails_helper'

RSpec.describe VendorInviteToken do
  let(:event) { create(:event) }

  it 'resolves a short code to the payload the old signed token carried' do
    link = described_class.issue(event_id: event.id, organizer_id: '7', group_id: 3)
    payload = described_class.verify(link.code)

    expect(payload).to include(event_id: event.id, organizer_id: 7, group_id: 3)
    expect(payload[:exp]).to eq(link.expires_at.to_i)
  end

  it 'gives different links for different groups, same link for same group' do
    a = described_class.issue(event_id: event.id, organizer_id: 7, group_id: 3)
    expect(described_class.issue(event_id: event.id, organizer_id: 7, group_id: 3)).to eq(a)
    expect(described_class.issue(event_id: event.id, organizer_id: 7)).not_to eq(a)
  end

  it 'still accepts a legacy signed token' do
    legacy = Rails.application.message_verifier(:vendor_invite)
                  .generate({ event_id: event.id, organizer_id: 7, exp: 1.day.from_now.to_i })

    expect(described_class.verify(legacy)).to include('event_id' => event.id)
  end

  it 'rejects unknown, expired and wrong-kind codes' do
    link = described_class.issue(event_id: event.id, organizer_id: 7)
    host = ShortLink.fetch(kind: 'host_invite', event_id: event.id, ttl: 1.day)

    expect { described_class.verify('nope') }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
    expect { described_class.verify(host.code) }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
    link.update!(expires_at: 1.minute.ago)
    expect { described_class.verify(link.code) }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
  end
end
