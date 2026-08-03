# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExhibitorTeamMemberTicketReconciliationService do
  let(:event) { create(:event, use_ticket: true) }
  let(:exhibitor) { create(:exhibitor, event: event) }
  let(:paid_kit) { create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :paid) }
  let(:unpaid_kit) { create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid) }

  it 'keeps attendee access when a paid sibling kit includes the same email' do
    email = 'shared@example.com'
    paid_member = create(:exhibitor_team_member, exhibitor_kit: paid_kit, email: email)
    unpaid_member = create(:exhibitor_team_member, exhibitor_kit: unpaid_kit, email: email.upcase)
    ticket = paid_member.reload.attendee

    described_class.new(unpaid_kit).call

    expect(unpaid_member.reload.attendee).to eq(ticket)
    expect(ticket.reload).to have_attributes(status: 'purchased', payment_status: 'paid')
  end

  it 'keeps shared attendee access when the member from one kit is removed' do
    email = 'shared@example.com'
    paid_member = create(:exhibitor_team_member, exhibitor_kit: paid_kit, email: email)
    unpaid_member = create(:exhibitor_team_member, exhibitor_kit: unpaid_kit, email: email)
    ticket = paid_member.reload.attendee

    unpaid_member.destroy!

    expect(Ticket.find_by(id: ticket.id)).to eq(ticket)
    expect(paid_member.reload.attendee).to eq(ticket)
  end

  it 'removes attendee access when only an unpaid sibling membership remains' do
    email = 'shared@example.com'
    paid_member = create(:exhibitor_team_member, exhibitor_kit: paid_kit, email: email)
    unpaid_member = create(:exhibitor_team_member, exhibitor_kit: unpaid_kit, email: email)
    ticket = paid_member.reload.attendee

    paid_member.destroy!

    expect(unpaid_member.reload.attendee).to eq(ticket)
    expect(ticket.reload).to have_attributes(status: 'pending_payment', payment_status: 'pending')
  end
end
