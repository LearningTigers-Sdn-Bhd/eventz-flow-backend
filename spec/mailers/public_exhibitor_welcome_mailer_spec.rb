require 'rails_helper'

RSpec.describe PublicExhibitorWelcomeMailer, type: :mailer do
  it 'sends warm credential instructions without bcc' do
    mail = described_class.welcome('vendor@example.com', 'Sabah-A1B2C3D4!', 'Illana Zamora')
    body = mail.body.encoded

    expect(mail.to).to eq(['vendor@example.com'])
    expect(mail.bcc).to be_blank
    expect(body).to include('vendor@example.com', 'Sabah-A1B2C3D4!', described_class::LOGIN_URL)
    expect(body).to include('Hi <strong>Illana Zamora</strong>', 'Your exhibitor account is ready', 'Account Details',
      'manage your booths', 'update exhibitor details where available',
      'add team members', 'order items and services', 'update your password promptly',
      'This is an automated email from EventzFlow')
  end
end
