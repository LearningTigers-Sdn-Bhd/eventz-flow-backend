require 'rails_helper'

RSpec.describe EmailDelivery::ArgsRebuilder do
  describe '.call' do
    it 'returns the related ticket for grouped confirmation emails' do
      ticket = create(:ticket, attendee_email: 'attendee@example.com')
      delivery = create(
        :email_delivery,
        related: ticket,
        mailer_name: 'TicketMailer',
        mailer_action: 'group_confirmation_email'
      )

      expect(described_class.call(delivery)).to eq([ticket])
    end
  end
end
