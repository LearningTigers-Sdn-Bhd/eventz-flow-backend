require 'rails_helper'

RSpec.describe EmailDelivery::ArgsRebuilder do
  describe '.call' do
    {
      'thank_you_email' => :ticket,
      'feedback_reminder_email' => :ticket,
      'exhibitor_thank_you_email' => :event_vendor,
      'exhibitor_feedback_reminder_email' => :event_vendor
    }.each do |action, factory|
      it "rebuilds #{action} for retry" do
        related = create(factory)
        delivery = build(:email_delivery, related: related, mailer_name: 'ThankYouMailer', mailer_action: action)

        expect(described_class.call(delivery)).to eq([related])
      end

      it "rejects #{action} with the wrong related type" do
        delivery = build(:email_delivery, related: build(:user), mailer_name: 'ThankYouMailer', mailer_action: action)

        expect(described_class.call(delivery)).to be_nil
      end
    end

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
