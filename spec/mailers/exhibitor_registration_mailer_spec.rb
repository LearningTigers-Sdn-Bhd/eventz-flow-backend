require 'rails_helper'

RSpec.describe ExhibitorRegistrationMailer, type: :mailer do
  let(:event) { create(:event, title: 'OGSE Sabah 2026') }
  let(:vendor) { create(:user, :vendor, email: 'exhibitor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:booth_price) do
    create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', label: 'International', price: 9000)
  end
  let(:exhibitor_kit) do
    create(
      :exhibitor_kit,
      event_vendor: exhibitor,
      exhibitor_booth_price: booth_price,
      company_name: 'Acme Energy',
      pic_full_name: 'Amin Rahman',
      pic_email_address: 'exhibitor@example.com',
      amount_paid: 9000,
      payment_status: :unpaid
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

    before do
      create(
        :exhibitor_registration_payment,
        exhibitor_kit: exhibitor_kit,
        amount: 9000,
        status: 'paid',
        gateway_payment_id: 'pay_exhibitor_123',
        payment_method: 'fpx',
        paid_at: Time.zone.parse('2026-02-28 10:20:00 +08:00'),
        gateway_response: { order_id: 'order_exhibitor_123' }
      )
    end

    it 'renders subject and recipient' do
      expect(mail.subject).to eq('Exhibitor payment confirmed for OGSE Sabah 2026')
      expect(mail.to).to eq(['exhibitor@example.com'])
    end

    it 'includes company and contact person' do
      expect(mail.body.encoded).to include('Acme Energy')
      expect(mail.body.encoded).to include('Amin Rahman')
    end

    it 'adds internal receipt bcc recipients' do
      expect(mail.bcc).to include('eventpayment@eventzflow.com')
    end

    it 'adds organizer payment receipt bcc from event' do
      event.create_event_email_setting!(payment_receipt_email: 'organizer@example.com')

      organizer_mail = described_class.payment_confirmed_email(exhibitor_kit)
      expect(organizer_mail.bcc).to include('organizer@example.com')
    end

    it 'includes payment receipt details' do
      expect(mail.body.encoded).to include('Payment Receipt')
      expect(mail.body.encoded).to include('Receipt No')
      expect(mail.body.encoded).to include("EXH-#{exhibitor_kit.id}")
      expect(mail.body.encoded).to include('Amount Paid')
      expect(mail.body.encoded).to include('MYR 9000.00')
      expect(mail.body.encoded).to include('pay_exhibitor_123')
      expect(mail.body.encoded).to include('order_exhibitor_123')
    end

    it 'styles payment receipt labels with distinct header color' do
      expect(mail.body.encoded).to include('color: #166534;')
    end
  end
end
