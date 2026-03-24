require "rails_helper"

RSpec.describe ExhibitorRegistrationPayment, type: :model do
  include ActiveJob::TestHelper

  describe "associations" do
    it { should belong_to(:exhibitor_kit) }
  end

  describe "validations" do
    subject(:payment) { build(:exhibitor_registration_payment) }

    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { should validate_inclusion_of(:status).in_array(%w[pending paid failed refunded]) }
  end

  describe "scopes" do
    let!(:pending_payment) { create(:exhibitor_registration_payment, status: "pending") }
    let!(:paid_payment) { create(:exhibitor_registration_payment, status: "paid") }
    let!(:failed_payment) { create(:exhibitor_registration_payment, status: "failed") }

    it "returns pending records" do
      expect(described_class.pending).to contain_exactly(pending_payment)
    end

    it "returns paid records" do
      expect(described_class.paid).to contain_exactly(paid_payment)
    end

    it "returns failed records" do
      expect(described_class.failed).to contain_exactly(failed_payment)
    end
  end

  describe "#mark_as_paid!" do
    let(:exhibitor_kit) { create(:exhibitor_kit, payment_status: :unpaid) }
    let(:payment) { create(:exhibitor_registration_payment, exhibitor_kit: exhibitor_kit, status: "pending") }

    before do
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
    end

    it "updates payment and exhibitor kit statuses" do
      payment.mark_as_paid!(payment_method: "fpx", gateway_response: { order_id: "order_1" })

      expect(payment.reload.status).to eq("paid")
      expect(payment.paid_at).to be_present
      expect(payment.payment_method).to eq("fpx")
      expect(exhibitor_kit.reload.payment_status).to eq("paid")
    end

    it 'upgrades free team member tickets and enqueues their confirmation emails' do
      team_member = create(
        :exhibitor_team_member,
        exhibitor_kit: exhibitor_kit,
        full_name: 'Paid Later Member',
        email: 'paid-later@example.com',
        phone: '+60123456789'
      )
      ticket = team_member.reload.attendee

      expect(ticket.status).to eq('pending_payment')
      expect(ticket.payment_status).to eq('pending')

      expect do
        payment.mark_as_paid!(payment_method: 'fpx', gateway_response: { order_id: 'order_1' })
      end.to have_enqueued_mail(TicketMailer, :confirmation_email).exactly(3).times

      ticket.reload
      expect(ticket.status).to eq('purchased')
      expect(ticket.payment_status).to eq('paid')
    end
  end

  describe "#mark_as_failed!" do
    let(:exhibitor_kit) { create(:exhibitor_kit, payment_status: :paid) }
    let(:payment) { create(:exhibitor_registration_payment, exhibitor_kit: exhibitor_kit, status: "pending") }

    it "updates payment and exhibitor kit statuses" do
      payment.mark_as_failed!(gateway_response: { reason: "declined" })

      expect(payment.reload.status).to eq("failed")
      expect(exhibitor_kit.reload.payment_status).to eq("unpaid")
    end
  end
end
