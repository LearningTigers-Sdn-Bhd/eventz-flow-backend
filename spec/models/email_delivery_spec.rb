require 'rails_helper'

RSpec.describe EmailDelivery, type: :model do
  describe 'validations' do
    subject(:delivery) do
      build(
        :email_delivery,
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        recipient: 'attendee@example.com'
      )
    end

    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:mailer_name) }
    it { is_expected.to validate_presence_of(:mailer_action) }
    it { is_expected.to validate_inclusion_of(:status).in_array(EmailDelivery::STATUSES) }
  end

  describe '#delivered_successfully?' do
    it 'returns true only for delivered records' do
      expect(build(:email_delivery, status: 'delivered')).to be_delivered_successfully
      expect(build(:email_delivery, status: 'sent')).not_to be_delivered_successfully
    end
  end

  describe '#eligible_for_manual_resend?' do
    it 'allows failed records' do
      expect(build(:email_delivery, status: 'failed')).to be_eligible_for_manual_resend
    end

    it 'allows sent records older than 24 hours' do
      travel_to(Time.zone.local(2026, 5, 16, 0, 0, 0)) do
        delivery = build(:email_delivery, status: 'sent', sent_at: 25.hours.ago)
        expect(delivery).to be_eligible_for_manual_resend
      end
    end

    it 'blocks delivered and bounced records' do
      expect(build(:email_delivery, status: 'delivered')).not_to be_eligible_for_manual_resend
      expect(build(:email_delivery, status: 'bounced')).not_to be_eligible_for_manual_resend
    end
  end
end
