require 'rails_helper'

RSpec.describe PublicExhibitorAccessMailer, type: :mailer do
  it 'contains challenge link without booking data or bcc' do
    event = create(:event, title: 'Expo')
    mail = described_class.access_link(event, 'vendor@example.com', 'one-use-token')

    expect(mail.to).to eq(['vendor@example.com'])
    expect(mail.bcc).to be_blank
    expect(mail.body.encoded).to include('one-use-token')
    expect(mail.body.encoded).to include('Access Your Booth Bookings', 'Access My Booth Bookings',
      'expires in 15 minutes', 'upload payment proof', 'This is an automated email from EventzFlow')
    expect(mail.body.encoded).not_to include('Company:', 'Amount Paid:', 'Payment Status:')
  end

  it 'allows a local HTTP registration URL outside production' do
    event = create(:event, title: 'Expo', public_registration_url: 'http://localhost:4321')

    mail = described_class.access_link(event, 'vendor@example.com', 'one-use-token')

    expect(mail.body.encoded).to include('http://localhost:4321/exhibitor-registration/access')
  end
end
