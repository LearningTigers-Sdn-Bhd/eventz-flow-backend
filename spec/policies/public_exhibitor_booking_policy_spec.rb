require 'rails_helper'

RSpec.describe PublicExhibitorBookingPolicy do
  let(:event) { create(:event) }
  let(:access) { create_access(event, 'owner@example.com') }
  let(:owned) { create_kit(event, 'owner@example.com') }
  let(:foreign) { create_kit(event, 'other@example.com') }

  it 'permits an active access session to list and create' do
    policy = described_class.new(access, ExhibitorKit)
    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
  end

  it 'permits owned records and denies foreign records' do
    expect(described_class.new(access, owned).show?).to be(true)
    expect(described_class.new(access, foreign).show?).to be(false)
  end

  def create_access(event, email)
    PublicExhibitorAccessSession.create!(event: event, normalized_email: email,
      challenge_digest: SecureRandom.hex(32), challenge_expires_at: 1.minute.ago,
      session_digest: SecureRandom.hex(32), expires_at: 1.hour.from_now)
  end

  def create_kit(event, email)
    exhibitor = create(:exhibitor, event: event, vendor: create(:user, :vendor, email: email))
    create(:exhibitor_kit, event_vendor: exhibitor)
  end
end
