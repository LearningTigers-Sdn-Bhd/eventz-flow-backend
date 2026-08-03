require 'rails_helper'

RSpec.describe EmailDeliveryRetryJob, type: :job do
  it 'retries transient failures in place via EmailDeliveryJob' do
    ticket = create(:ticket, attendee_email: 'attendee@example.com')
    delivery = create(
      :email_delivery,
      :failed,
      related: ticket,
      mailer_name: 'TicketMailer',
      mailer_action: 'confirmation_email',
      failure_reason: 'rate_limit',
      next_retry_at: 1.minute.ago
    )

    allow(EmailDeliveryJob).to receive(:perform_later)

    expect { described_class.perform_now }.to change { delivery.reload.retry_count }.by(1)

    expect(EmailDeliveryJob).to have_received(:perform_later).with(
      delivery.id, 'TicketMailer', 'confirmation_email', [ticket]
    )
  end

  it 'does not retry bounced emails' do
    create(:email_delivery, status: 'bounced', next_retry_at: 1.minute.ago)

    allow(EmailDeliveryJob).to receive(:perform_later)

    described_class.perform_now

    expect(EmailDeliveryJob).not_to have_received(:perform_later)
  end

  it 'stops re-picking deliveries whose type is unsupported for retry' do
    delivery = create(
      :email_delivery,
      :failed,
      related: nil,
      mailer_name: 'TicketMailer',
      mailer_action: 'confirmation_email',
      failure_reason: 'rate_limit',
      next_retry_at: 1.minute.ago
    )

    allow(EmailDeliveryJob).to receive(:perform_later)

    described_class.perform_now

    expect(EmailDeliveryJob).not_to have_received(:perform_later)
    expect(delivery.reload.next_retry_at).to be_nil
    expect(delivery.failure_reason).to eq('unsupported_retry')
  end
end
