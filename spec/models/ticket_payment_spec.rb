require 'rails_helper'

RSpec.describe TicketPayment, type: :model do
  describe 'associations' do
    it { should belong_to(:ticket) }
    it { should belong_to(:received_by).class_name('User').optional }
  end

  describe 'validations' do
    let(:ticket) { create(:ticket) }
    subject { create(:ticket_payment, ticket: ticket) }

    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { should validate_inclusion_of(:status).in_array(%w[pending paid failed refunded]) }
  end

  describe '#mark_as_paid!' do
    let(:ticket) { create(:ticket, payment_status: "pending") }
    let(:payment) { create(:ticket_payment, ticket: ticket, status: "pending") }

    it 'updates payment status to paid' do
      payment.mark_as_paid!(payment_method: "fpx")

      expect(payment.reload.status).to eq("paid")
      expect(payment.paid_at).to be_present
      expect(payment.payment_method).to eq("fpx")
    end

    it 'updates ticket payment status' do
      payment.mark_as_paid!

      expect(ticket.reload.payment_status).to eq("paid")
    end
  end

  describe '#mark_as_failed!' do
    let(:ticket) { create(:ticket, payment_status: "pending") }
    let(:payment) { create(:ticket_payment, ticket: ticket, status: "pending") }

    it 'updates payment status to failed' do
      payment.mark_as_failed!

      expect(payment.reload.status).to eq("failed")
    end

    it 'updates ticket payment status' do
      payment.mark_as_failed!

      expect(ticket.reload.payment_status).to eq("failed")
    end
  end

  describe '#online_payment?' do
    it 'returns true when gateway is present' do
      payment = build(:ticket_payment, gateway: "razorpay")
      expect(payment.online_payment?).to be true
    end

    it 'returns false when gateway is nil' do
      payment = build(:ticket_payment, gateway: nil)
      expect(payment.online_payment?).to be false
    end
  end

  describe '#cash_payment?' do
    it 'returns true when payment_method is cash' do
      payment = build(:ticket_payment, payment_method: "cash")
      expect(payment.cash_payment?).to be true
    end

    it 'returns false for other payment methods' do
      payment = build(:ticket_payment, payment_method: "fpx")
      expect(payment.cash_payment?).to be false
    end
  end
end
