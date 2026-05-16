require 'rails_helper'

RSpec.describe EmailDeliveryRetryJob, type: :job do
  it 'retries transient failures whose retry window has opened' do
    delivery = create(
      :email_delivery,
      :failed,
      failure_reason: 'rate_limit',
      next_retry_at: 1.minute.ago
    )

    allow(EmailDelivery::Resender).to receive(:call)

    described_class.perform_now

    expect(EmailDelivery::Resender).to have_received(:call).with(delivery)
  end

  it 'does not retry bounced emails' do
    create(:email_delivery, status: 'bounced', next_retry_at: 1.minute.ago)

    allow(EmailDelivery::Resender).to receive(:call)

    described_class.perform_now

    expect(EmailDelivery::Resender).not_to have_received(:call)
  end
end
