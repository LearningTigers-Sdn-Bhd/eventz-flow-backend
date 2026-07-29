require 'rails_helper'

RSpec.describe EmailDeliveryJob, type: :job do
  let(:ticket) { create(:ticket, attendee_email: 'attendee@example.com') }
  let(:delivery) do
    create(
      :email_delivery,
      related: ticket,
      mailer_name: 'TicketMailer',
      mailer_action: 'confirmation_email',
      status: 'queued'
    )
  end

  it 'does not log job arguments containing email credentials' do
    expect(described_class.log_arguments).to be(false)
  end

  it 'sends the queued audited delivery' do
    service = instance_double(EmailDelivery::AuditedDelivery, deliver_now: delivery)
    allow(EmailDelivery::AuditedDelivery).to receive(:new).and_return(service)

    described_class.perform_now(delivery.id, 'TicketMailer', 'confirmation_email', [ticket])

    expect(service).to have_received(:deliver_now).with(delivery)
  end
end
