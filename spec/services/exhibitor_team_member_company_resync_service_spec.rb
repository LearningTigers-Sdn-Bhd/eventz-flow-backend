require 'rails_helper'

RSpec.describe ExhibitorTeamMemberCompanyResyncService do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_ticket: true) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }
  let(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor, company_name: 'Correct Co') }

  around do |example|
    ActiveJob::Base.queue_adapter = :test
    exhibitor_kit
    clear_enqueued_jobs
    example.run
  end

  def member_with_ticket(name:)
    member = create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, full_name: name)
    member.reload
  end

  it 'updates a ticket whose custom_fields_data has a stale company name' do
    member = member_with_ticket(name: 'Jane Expo')
    member.attendee.update!(custom_fields_data: member.attendee.custom_fields_data.to_h.merge('company' => 'Old Typo Co'))

    result = described_class.new(exhibitor_kit).call

    expect(result[:updated].map { |r| r[:id] }).to eq([member.id])
    expect(member.attendee.reload.custom_fields_data['company']).to eq('Correct Co')
  end

  it 'leaves already-correct tickets in unchanged, not updated' do
    member = member_with_ticket(name: 'Jane Expo')
    expect(member.attendee.custom_fields_data['company']).to eq('Correct Co')

    result = described_class.new(exhibitor_kit).call

    expect(result[:updated]).to be_empty
    expect(result[:unchanged].map { |r| r[:id] }).to include(member.id)
  end

  it 'skips members without a linked ticket' do
    member = create(:exhibitor_team_member, exhibitor_kit: exhibitor_kit, full_name: 'No Ticket')
    member.update_columns(attendee_type: nil, attendee_id: nil)

    result = described_class.new(exhibitor_kit).call

    expect(result[:skipped].map { |r| r[:id] }).to include(member.id)
    expect(result[:updated]).to be_empty
  end

  it 'skips everything when the kit has no company name set' do
    exhibitor_kit.update_column(:company_name, '')
    member = member_with_ticket(name: 'Jane Expo')

    result = described_class.new(exhibitor_kit).call

    expect(result[:skipped].map { |r| r[:id] }).to include(member.id)
    expect(result[:updated]).to be_empty
  end

  it 'never touches ticket status or payment_status' do
    member = member_with_ticket(name: 'Jane Expo')
    member.attendee.update!(
      status: :scanned,
      payment_status: :paid,
      custom_fields_data: member.attendee.custom_fields_data.to_h.merge('company' => 'Old Typo Co')
    )

    described_class.new(exhibitor_kit).call

    ticket = member.attendee.reload
    expect(ticket.status).to eq('scanned')
    expect(ticket.payment_status).to eq('paid')
    expect(ticket.custom_fields_data['company']).to eq('Correct Co')
  end
end
