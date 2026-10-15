require 'rails_helper'

RSpec.describe TicketApplicationReviewService do
  include ActiveJob::TestHelper

  let(:reviewer) { create(:user, :organizer) }
  let(:event) { create(:event, title: 'Sabah Impact Summit') }
  let(:registration_form) { create(:registration_form, event: event, name: 'Interested Delegate', slug: 'interested-delegate') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate Pass') }
  let(:ticket) { create(:ticket, :pending_payment, event: event, ticket_type: ticket_type) }
  let(:application) { create(:ticket_application, ticket: ticket, registration_form: registration_form) }

  before do
    create(:registration_form_rsvp_setting, registration_form: registration_form, enabled: true, rsvp_required: true, rsvp_expires_in_hours: nil)
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe '#approve!' do
    it 'approves, sends RSVP, and does not purchase the ticket when RSVP is required' do
      perform_enqueued_jobs do
        described_class.new(application, reviewer: reviewer).approve!
      end

      application.reload
      ticket.reload

      expect(application.review_status).to eq('approved')
      expect(application.rsvp_status).to eq('sent')
      expect(application.reviewed_by).to eq(reviewer)
      expect(application.reviewed_at).to be_present
      expect(application.rsvp_sent_at).to be_present
      expect(application.rsvp_token_digest).to be_present
      expect(application.rsvp_expires_at).to be_nil
      expect(ticket.status).to eq('pending_payment')
      expect(ticket.payment_status).to eq('pending')
      expect(ActionMailer::Base.deliveries.map(&:subject)).to include('RSVP required for Sabah Impact Summit')
    end

    it 'purchases the ticket immediately when RSVP is not required' do
      registration_form.registration_form_rsvp_setting.update!(rsvp_required: false)

      described_class.new(application, reviewer: reviewer).approve!

      expect(application.reload.review_status).to eq('approved')
      expect(ticket.reload.status).to eq('purchased')
      expect(ticket.payment_status).to eq('paid')
    end
  end

  describe '#reject!' do
    it 'rejects application, cancels ticket, and sends rejection email' do
      perform_enqueued_jobs do
        described_class.new(application, reviewer: reviewer).reject!(reason: 'Seats reached')
      end

      application.reload
      ticket.reload

      expect(application.review_status).to eq('rejected')
      expect(application.rejection_reason).to eq('Seats reached')
      expect(ticket.status).to eq('canceled')
      expect(ActionMailer::Base.deliveries.map(&:subject)).to include('Application update for Sabah Impact Summit')
    end
  end

  describe '#revert_to_pending!' do
    it 'reverts an approved, manually-paid ticket back to pending' do
      registration_form.registration_form_rsvp_setting.update!(rsvp_required: false)
      described_class.new(application, reviewer: reviewer).approve!
      create(:ticket_payment, ticket: ticket, status: 'paid', gateway: nil)

      result = described_class.new(application, reviewer: reviewer).revert_to_pending!

      expect(result.success?).to eq(true)
      expect(application.reload.review_status).to eq('pending_review')
      expect(application.reviewed_by).to be_nil
      expect(application.reviewed_at).to be_nil
      expect(ticket.reload.status).to eq('pending_payment')
      expect(ticket.payment_status).to eq('pending')
      expect(ticket.ticket_payment.reload.status).to eq('refunded')
    end

    it 'blocks revert when the ticket was paid via a gateway, unless confirmed' do
      registration_form.registration_form_rsvp_setting.update!(rsvp_required: false)
      described_class.new(application, reviewer: reviewer).approve!
      create(:ticket_payment, ticket: ticket, status: 'paid', gateway: 'razorpay')

      result = described_class.new(application, reviewer: reviewer).revert_to_pending!

      expect(result.success?).to eq(false)
      expect(result.error).to match(/gateway/i)
      expect(application.reload.review_status).to eq('approved')

      confirmed_result = described_class.new(application, reviewer: reviewer).revert_to_pending!(confirm_manual_refund: true)
      expect(confirmed_result.success?).to eq(true)
      expect(application.reload.review_status).to eq('pending_review')
    end

    it 'blocks revert when the ticket has already been checked in' do
      described_class.new(application, reviewer: reviewer).approve!
      ticket.update!(status: :scanned)

      result = described_class.new(application, reviewer: reviewer).revert_to_pending!

      expect(result.success?).to eq(false)
      expect(result.error).to match(/checked in/i)
    end

    it 'rejects revert when the application is not approved' do
      result = described_class.new(application, reviewer: reviewer).revert_to_pending!

      expect(result.success?).to eq(false)
      expect(result.error).to eq('Application is not approved')
    end
  end

  describe '#confirm_rsvp!' do
    it 'confirms RSVP and converts the ticket into a QR-confirmed ticket' do
      raw_token = described_class.new(application, reviewer: reviewer).approve!

      described_class.new(application).confirm_rsvp!(raw_token: raw_token)

      application.reload
      ticket.reload

      expect(application.rsvp_status).to eq('confirmed')
      expect(application.rsvp_confirmed_at).to be_present
      expect(ticket.status).to eq('purchased')
      expect(ticket.payment_status).to eq('paid')
    end

    it 'marks expired RSVP as expired and does not purchase the ticket' do
      raw_token = application.assign_rsvp_token!
      application.update!(review_status: :approved, rsvp_status: :sent, rsvp_expires_at: 1.hour.ago)

      result = described_class.new(application).confirm_rsvp!(raw_token: raw_token)

      expect(result.success?).to eq(false)
      expect(result.error).to eq('RSVP link has expired')
      expect(application.reload.rsvp_status).to eq('expired')
      expect(ticket.reload.status).to eq('pending_payment')
    end
  end
end
