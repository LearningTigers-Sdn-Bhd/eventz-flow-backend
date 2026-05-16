require 'rails_helper'

RSpec.describe EmailDelivery::HistoricalBackfill do
  it 'imports provider-only Resend rows without duplicates' do
    rows = [
      {
        'id' => 'email_123',
        'to' => ['attendee@example.com'],
        'subject' => 'Your ticket for OGSE Sabah 2026',
        'created_at' => '2026-05-15T01:00:00Z',
        'last_event' => 'delivered'
      }
    ]

    expect do
      described_class.call(rows)
      described_class.call(rows)
    end.to change(EmailDelivery, :count).by(1)

    delivery = EmailDelivery.find_by!(provider_message_id: 'email_123')
    expect(delivery.status).to eq('delivered')
    expect(delivery.metadata['historical_backfill']).to eq(true)
  end
end
