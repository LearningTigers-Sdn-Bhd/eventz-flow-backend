require 'rails_helper'

RSpec.describe 'Event membership uniqueness', type: :model do
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }

  def register(fields)
    create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: fields)
  end

  it 'defaults to enforcing membership uniqueness, including multiple-ticket events' do
    event.update!(allow_multiple_tickets_per_email: true)
    register('membership_no' => 'MEM001')
    duplicate = build(:ticket, event: event, ticket_type: ticket_type,
                              custom_fields_data: { 'membership_no' => 'mem001' })
    expect(event.require_unique_membership_numbers).to be(true)
    expect(duplicate).not_to be_valid
  end

  it 'allows shared memberships without relaxing IC uniqueness or another event' do
    event.update!(require_unique_membership_numbers: false)
    register('membership_no' => 'MEM001', 'ic_passport_no' => 'IC001')
    expect { register('membership_no' => 'mem001') }.not_to raise_error
    expect { register('ic_passport_no' => 'IC001') }.to raise_error(ActiveRecord::RecordInvalid)
    other_event = create(:event)
    other_type = create(:ticket_type, event: other_event)
    create(:ticket, event: other_event, ticket_type: other_type, custom_fields_data: { 'membership_no' => 'MEM001' })
    expect { create(:ticket, event: other_event, ticket_type: other_type,
                            custom_fields_data: { 'membership_no' => 'mem001' }) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'rejects re-enabling until active duplicates are resolved and syncs archived tickets' do
    event.update!(require_unique_membership_numbers: false)
    first = register('membership_no' => 'MEM001')
    duplicate = register('membership_no' => 'mem001')
    expect(event.update(require_unique_membership_numbers: true)).to be(false)
    expect(event.errors.full_messages.join).to include('duplicate membership')
    expect(event.reload.require_unique_membership_numbers).to be(false)
    duplicate.archive
    event.update!(require_unique_membership_numbers: true)
    expect(first.reload.require_unique_membership_numbers).to be(true)
    expect(duplicate.reload.require_unique_membership_numbers).to be(true)
    expect { duplicate.update_columns(deleted_at: nil) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'uses the current setting even when the associated event was loaded before a toggle' do
    register('membership_no' => 'MEM001')
    stale_event = Event.find(event.id)
    event.update!(require_unique_membership_numbers: false)
    ticket = build(:ticket, event: stale_event, ticket_type: ticket_type,
                            custom_fields_data: { 'membership_no' => 'MEM001' })
    expect { ticket.save! }.not_to raise_error
    expect(ticket.require_unique_membership_numbers).to be(false)
  end

  it 'enforces the index even when model validation is skipped' do
    register('membership_no' => 'MEM001')
    duplicate = build(:ticket, event: event, ticket_type: ticket_type,
                              custom_fields_data: { 'membership_no' => 'mem001' })
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
