require 'rails_helper'

RSpec.describe ExhibitorTeamMemberPaymentVerificationService do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_ticket: true) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

  # Limit of 3, fee 50 per extra
  let!(:team_member_limit) do
    create(:exhibitor_team_member_limit, event: event, team_member_limit: 3, extra_team_member_fee: 50.00)
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    # exhibitor_kit factory creates 2 members (within limit)
    exhibitor_kit
    exhibitor_kit.update!(payment_status: :paid)
    clear_enqueued_jobs
  end

  describe '#call' do
    context 'when payment is verified for excess members' do
      let!(:third_member) { create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, email: 'third@example.com', phone: '+60333333333') }
      let!(:excess_member) { create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, full_name: 'Excess One', email: 'excess1@example.com', phone: '+60444444444') }

      let!(:payment) do
        create(:exhibitor_team_member_payment, :submitted,
          exhibitor_kit: exhibitor_kit,
          extra_member_count: 1,
          fee_per_member: 50.0,
          amount: 50.0
        )
      end

      it 'upgrades pending tickets to purchased/paid' do
        excess_ticket = excess_member.reload.attendee
        expect(excess_ticket.status).to eq('pending_payment')
        expect(excess_ticket.payment_status).to eq('pending')

        described_class.new(payment).call

        excess_ticket.reload
        expect(excess_ticket.status).to eq('purchased')
        expect(excess_ticket.payment_status).to eq('paid')
      end

      it 'triggers a confirmation email for the upgraded ticket' do
        clear_enqueued_jobs

        expect do
          described_class.new(payment).call
        end.to have_enqueued_job(EmailDeliveryJob)
      end

      it 'does not upgrade more tickets than extra_member_count' do
        second_excess = create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, full_name: 'Excess Two', email: 'excess2@example.com', phone: '+60555555555')

        # Payment covers only 1 extra member
        described_class.new(payment).call

        # First excess should be upgraded
        expect(excess_member.reload.attendee.status).to eq('purchased')
        # Second excess should remain pending
        expect(second_excess.reload.attendee.status).to eq('pending_payment')
      end
    end

    context 'when there are no pending tickets' do
      it 'completes without error' do
        payment = create(:exhibitor_team_member_payment, :submitted,
          exhibitor_kit: exhibitor_kit,
          extra_member_count: 1,
          fee_per_member: 50.0,
          amount: 50.0
        )

        expect { described_class.new(payment).call }.not_to raise_error
      end
    end
  end
end
