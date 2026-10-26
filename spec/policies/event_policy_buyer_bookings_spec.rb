require 'rails_helper'

RSpec.describe EventPolicy, '#buyer_bookings?' do
  let(:event) { create(:event, use_business_matching: true) }

  it 'allows a business host of the event' do
    host = create(:user, role: :member)
    BusinessHostAssignment.create!(event: event, user: host, business_matching_event_id: '1')
    expect(described_class.new(host, event).buyer_bookings?).to be(true)
  end

  it 'allows an organizer' do
    expect(described_class.new(create(:user, :organizer), event).buyer_bookings?).to be(true)
  end

  it 'denies a member with no business matching role' do
    expect(described_class.new(create(:user, :member), event).buyer_bookings?).to be(false)
  end

  it 'denies everyone when business matching is off for the event' do
    event.update!(use_business_matching: false)
    expect(described_class.new(create(:user, :organizer), event).buyer_bookings?).to be(false)
  end

  it 'denies a missing user' do
    expect(described_class.new(nil, event).buyer_bookings?).to be(false)
  end
end

RSpec.describe EventPolicy, '#seller_buyer_bookings?' do
  let(:event) { create(:event, use_business_matching: true) }

  it 'allows staff who manage sessions' do
    expect(described_class.new(create(:user, :organizer), event).seller_buyer_bookings?).to be(true)
    expect(described_class.new(create(:user, :org_owner), event).seller_buyer_bookings?).to be(true)
  end

  it 'denies a business host' do
    host = create(:user, role: :member)
    BusinessHostAssignment.create!(event: event, user: host, business_matching_event_id: '1')
    expect(described_class.new(host, event).seller_buyer_bookings?).to be(false)
  end

  it 'denies a missing user' do
    expect(described_class.new(nil, event).seller_buyer_bookings?).to be(false)
  end
end
