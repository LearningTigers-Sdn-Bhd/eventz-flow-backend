require 'rails_helper'

RSpec.describe ExhibitorRegistrationMailer, type: :mailer do
  let(:event) { create(:event, title: 'OGSE Sabah 2026') }
  let(:vendor) { create(:user, :vendor, email: 'exhibitor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', label: 'International', price: 9000) }
  let(:exhibitor_kit) do
    create(
      :exhibitor_kit,
      event_vendor: exhibitor,
      exhibitor_booth_price: booth_price,
      company_name: 'Acme Energy',
      pic_full_name: 'Amin Rahman',
      pic_email_address: 'exhibitor@example.com',
      amount_paid: 9000,
      payment_status: :unpaid,
    )
  end

  describe '#registration_received_email' do
    let(:mail) { described_class.registration_received_email(exhibitor_kit) }

    it 'renders subject and recipient' do
      expect(mail.subject).to eq('Exhibitor registration received for OGSE Sabah 2026')
      expect(mail.to).to eq(['exhibitor@example.com'])
    end

    it 'includes booth and amount details' do
      expect(mail.body.encoded).to include('International')
      expect(mail.body.encoded).to include('RM 9000.0')
    end
  end

  describe '#payment_confirmed_email' do
    let(:mail) { described_class.payment_confirmed_email(exhibitor_kit) }

    it 'renders subject and recipient' do
      expect(mail.subject).to eq('Exhibitor payment confirmed for OGSE Sabah 2026')
      expect(mail.to).to eq(['exhibitor@example.com'])
    end

    it 'includes company and contact person' do
      expect(mail.body.encoded).to include('Acme Energy')
      expect(mail.body.encoded).to include('Amin Rahman')
    end
  end
end
