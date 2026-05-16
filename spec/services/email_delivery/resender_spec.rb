require 'rails_helper'

RSpec.describe EmailDelivery::Resender do
  describe '.call' do
    it 'resends failed ticket confirmation emails' do
      ticket = create(:ticket, attendee_email: 'attendee@example.com')
      original = create(
        :email_delivery,
        :failed,
        related: ticket,
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email'
      )

      new_delivery = create(:email_delivery, status: 'queued')
      allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later).and_return(new_delivery)

      result = described_class.call(original)

      expect(result.success?).to be true
      expect(EmailDelivery::AuditedDelivery).to have_received(:deliver_later).with(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket,
        metadata: hash_including(resend_of_id: original.id)
      )
    end

    it 'blocks bounced emails' do
      original = create(:email_delivery, status: 'bounced')

      result = described_class.call(original)

      expect(result.success?).to be false
      expect(result.errors).to include('Email is not eligible for resend')
    end
  end
end
