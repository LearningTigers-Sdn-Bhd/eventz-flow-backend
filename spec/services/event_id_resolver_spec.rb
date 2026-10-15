# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventIdResolver do
  it 'resolves a direct event id and rejects nonnumeric values' do
    expect(described_class.resolve(event_id: '42')).to eq(42)
    expect(described_class.resolve(event_id: 'not-an-id')).to be_nil
  end

  it 'resolves the events controller id' do
    expect(described_class.resolve(controller: 'v1/events', id: '12')).to eq(12)
    expect(described_class.resolve(controller: 'v1/tickets', id: '12')).to be_nil
  end

  it 'resolves a public ticket id' do
    ticket = create(:ticket)
    expect(described_class.resolve(public_id: ticket.public_id)).to eq(ticket.event_id)
  end

  it 'resolves an event slug' do
    event = create(:event)
    expect(described_class.resolve(event_slug: event.slug)).to eq(event.id)
  end

  it 'resolves a public visitor id' do
    visitor = create(:visitor)
    expect(described_class.resolve(public_id: visitor.public_id)).to eq(visitor.event_id)
  end
end
