require 'rails_helper'

RSpec.describe EmailDelivery::WebhookProcessor do
  let(:delivery) { create(:email_delivery, :sent) }
  let(:event) do
    {
      type: 'email.suppressed',
      data: {
        email_id: delivery.provider_message_id,
        suppressed: { type: 'OnAccountSuppressionList', message: 'Provider-only details' }
      }
    }
  end

  it 'records suppression instead of leaving the email sent' do
    described_class.call(event)

    expect(delivery.reload).to have_attributes(status: 'suppressed', failure_reason: 'suppressed')
    expect(delivery.metadata['webhook_events'].last['type']).to eq('email.suppressed')
  end

  it 'does not let a late sent event overwrite suppression' do
    described_class.call(event)
    described_class.call(event.merge(type: 'email.sent'))

    expect(delivery.reload.status).to eq('suppressed')
  end

  it 'logs account-level events as errors and touches no delivery' do
    allow(Rails.logger).to receive(:error)

    described_class.call(type: 'quota.paused', data: { reason: 'limit' })

    expect(Rails.logger).to have_received(:error).with(/quota\.paused/)
    expect(delivery.reload.status).to eq('sent')
  end

  it 'does not overwrite an existing final delivery status' do
    delivery.update!(status: 'delivered')
    described_class.call(event)

    expect(delivery.reload.status).to eq('delivered')
  end
end
