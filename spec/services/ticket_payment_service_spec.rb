require 'rails_helper'

RSpec.describe TicketPaymentService do
  let(:ticket) { create(:ticket, payment_status: "pending") }
  let(:staff) { create(:user) }

  describe '.create_cash_payment' do
    it 'creates a paid cash payment' do
      payment = described_class.create_cash_payment(
        ticket: ticket,
        amount: 80.00,
        received_by: staff,
        notes: "Walk-in customer"
      )

      expect(payment).to be_persisted
      expect(payment.status).to eq("paid")
      expect(payment.payment_method).to eq("cash")
      expect(payment.received_by).to eq(staff)
      expect(payment.notes).to eq("Walk-in customer")
    end

    it 'updates ticket payment_status to paid' do
      described_class.create_cash_payment(
        ticket: ticket,
        amount: 80.00,
        received_by: staff
      )

      expect(ticket.reload.payment_status).to eq("paid")
    end
  end

  describe '.create_online_payment' do
    it 'creates a pending online payment' do
      payment = described_class.create_online_payment(
        ticket: ticket,
        amount: 80.00,
        gateway: "razorpay",
        gateway_payment_id: "pay_123"
      )

      expect(payment).to be_persisted
      expect(payment.status).to eq("pending")
      expect(payment.gateway).to eq("razorpay")
      expect(payment.gateway_payment_id).to eq("pay_123")
    end
  end

  describe '.create_comp_payment' do
    it 'creates a complimentary payment with zero amount' do
      payment = described_class.create_comp_payment(ticket: ticket)

      expect(payment).to be_persisted
      expect(payment.status).to eq("paid")
      expect(payment.amount).to eq(0)
      expect(payment.payment_method).to eq("comp")
    end

    it 'updates ticket payment_status to paid' do
      described_class.create_comp_payment(ticket: ticket)

      expect(ticket.reload.payment_status).to eq("paid")
    end
  end
end
