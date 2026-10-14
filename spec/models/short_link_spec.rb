require 'rails_helper'

RSpec.describe ShortLink do
  let(:event) { create(:event) }

  it 'reuses the active link for the same kind, event and payload' do
    a = described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day, payload: { 'x' => 1 })
    b = described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day, payload: { 'x' => 1 })

    expect(b).to eq(a)
    expect(a.code.length).to eq(8)
  end

  it 'makes a new link when payload, kind or expiry differs' do
    a = described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day, payload: { 'x' => 1 })
    expect(described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day, payload: { 'x' => 2 })).not_to eq(a)
    expect(described_class.fetch(kind: 'other', event_id: event.id, ttl: 1.day, payload: { 'x' => 1 })).not_to eq(a)

    a.update!(expires_at: 1.minute.ago)
    expect(described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day, payload: { 'x' => 1 })).not_to eq(a)
  end

  it 'only looks a code up under its own kind' do
    link = described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day)

    expect(described_class.lookup(link.code, kind: 'k')).to eq(link)
    expect(described_class.lookup(link.code, kind: 'other')).to be_nil
  end

  it 'is removed with its event instead of blocking the delete' do
    described_class.fetch(kind: 'k', event_id: event.id, ttl: 1.day)

    expect { event.destroy! }.to change(described_class, :count).by(-1)
  end
end
