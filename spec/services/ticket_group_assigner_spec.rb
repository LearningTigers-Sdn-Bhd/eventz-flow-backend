require 'rails_helper'

RSpec.describe TicketGroupAssigner do
  let(:event) { create(:event) }
  let(:vip) { create(:ticket_type, event: event, name: 'VIP') }
  let(:delegate) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:student) { create(:ticket_type, event: event, name: 'Student') }
  let!(:groups) { (1..4).map { |n| event.ticket_groups.create!(name: "Room #{n}", position: n) } }

  def make_tickets(type, count)
    count.times do |i|
      create(:ticket, event: event, ticket_type: type, status: :purchased, payment_status: :paid,
                      attendee_name: "#{type.name} #{i}", attendee_email: "#{type.name.downcase}#{i}@example.com")
    end
  end

  # 6 VIP + 25 Delegate + 9 Student = 40 tickets, target 10 per group.
  before do
    make_tickets(vip, 6)
    make_tickets(delegate, 25)
    make_tickets(student, 9)
  end

  it 'fills the priority type first and balances every group' do
    groups.first.update!(priority_ticket_type_ids: [vip.id])
    result = described_class.new(event).call

    expect(result.counts.values).to all(eq(10))
    expect(result.by_type[groups.first.id][vip.id]).to eq(6)
    expect(result.assignments.size).to eq(40)
  end

  it 'lets a priority type spill when it is bigger than the target' do
    groups.first.update!(priority_ticket_type_ids: [delegate.id])
    result = described_class.new(event).call

    expect(result.by_type[groups.first.id][delegate.id]).to eq(10)
    expect(result.counts.values).to all(eq(10))
  end

  it 'mixes several priority types evenly instead of draining the first one' do
    groups.first.update!(priority_ticket_type_ids: [vip.id, student.id])
    result = described_class.new(event).call

    expect(result.by_type[groups.first.id]).to eq(vip.id => 5, student.id => 5)
    expect(result.counts.values).to all(eq(10))
  end

  it 'does not depend on the order the types were picked' do
    groups.first.update!(priority_ticket_type_ids: [student.id, vip.id])
    result = described_class.new(event).call

    expect(result.by_type[groups.first.id]).to eq(student.id => 5, vip.id => 5)
  end

  it 'takes the rest from the other picked types once one runs out' do
    tiny = create(:ticket_type, event: event, name: 'Tiny')
    make_tickets(tiny, 2) # 42 tickets, target 11
    groups.first.update!(priority_ticket_type_ids: [tiny.id, delegate.id])
    result = described_class.new(event).call

    expect(result.by_type[groups.first.id]).to eq(tiny.id => 2, delegate.id => 9)
  end

  describe 'fill mode "ordered" (the original behaviour)' do
    before { event.update!(ticket_group_fill_mode: 'ordered') }

    it 'drains the picked types in the order listed' do
      groups.first.update!(priority_ticket_type_ids: [vip.id, student.id])
      result = described_class.new(event).call

      expect(result.by_type[groups.first.id]).to eq(vip.id => 6, student.id => 4)
      expect(result.counts.values).to all(eq(10))
    end

    it 'respects the listed order when the first type is bigger' do
      groups.first.update!(priority_ticket_type_ids: [student.id, vip.id])
      result = described_class.new(event).call

      expect(result.by_type[groups.first.id]).to eq(student.id => 9, vip.id => 1)
    end

    it 'splits a type evenly between groups that share it' do
      groups.first(2).each { |g| g.update!(priority_ticket_type_ids: [vip.id]) }
      result = described_class.new(event).call

      expect(result.by_type[groups[0].id][vip.id]).to eq(3)
      expect(result.by_type[groups[1].id][vip.id]).to eq(3)
    end
  end

  describe 'excluded ticket types' do
    before { event.update!(ticket_group_excluded_type_ids: [vip.id]) }

    it 'never places them and balances the rest' do
      result = described_class.new(event).call

      expect(result.assignments.size).to eq(34)
      expect(result.counts.values.sum).to eq(34)
      expect(result.by_type.values.flat_map(&:keys)).not_to include(vip.id)
    end

    it 'takes already grouped tickets of that type out of their group' do
      ticket = event.tickets.find_by!(ticket_type: vip)
      ticket.update_columns(ticket_group_id: groups.first.id)
      event.update!(ticket_group_excluded_type_ids: [vip.id, student.id])
      event.update!(ticket_group_excluded_type_ids: [vip.id])

      expect(ticket.reload.ticket_group_id).to be_nil
    end
  end

  it 'only accepts the two known fill modes' do
    expect(event.update(ticket_group_fill_mode: 'random')).to be(false)
    expect(event.update(ticket_group_fill_mode: 'ordered')).to be(true)
  end

  it 'gives the same answer every time (preview matches assign)' do
    groups.first.update!(priority_ticket_type_ids: [vip.id, student.id, delegate.id])
    expect(described_class.new(event).call.assignments).to eq(described_class.new(event).call.assignments)
  end

  it 'splits a type evenly between groups that share it' do
    groups.first(2).each { |g| g.update!(priority_ticket_type_ids: [vip.id]) }
    result = described_class.new(event).call

    expect(result.by_type[groups[0].id][vip.id]).to eq(3)
    expect(result.by_type[groups[1].id][vip.id]).to eq(3)
  end

  it 'reports which tickets arrive in each group, by type' do
    groups.first.update!(priority_ticket_type_ids: [vip.id])
    result = described_class.new(event).call

    expect(result.added_by_type[groups.first.id][vip.id]).to eq(6)
    expect(result.added_by_type.values.sum { |h| h.values.sum }).to eq(40)
  end

  it 'in :new mode keeps existing assignments and only places unassigned tickets' do
    described_class.new(event).call.assignments.each { |tid, gid| Ticket.where(id: tid).update_all(ticket_group_id: gid) }
    make_tickets(student, 4)

    result = described_class.new(event).call
    expect(result.assignments.size).to eq(4)
    expect(result.counts.values).to all(eq(11))
  end

  it 'ignores unpaid tickets' do
    create(:ticket, event: event, ticket_type: student, status: :purchased, payment_status: :pending,
                    attendee_name: 'Unpaid', attendee_email: 'unpaid@example.com')
    expect(described_class.new(event).call.assignments.size).to eq(40)
  end

  it 'rejects priority types from another event' do
    other = create(:ticket_type, event: create(:event), name: 'Other')
    expect(groups.first.update(priority_ticket_type_ids: [other.id])).to be(false)
  end
end

RSpec.describe 'Ticket auto-assign to a group' do
  let(:event) { create(:event, use_ticket_groups: true, auto_assign_ticket_groups: true) }
  let(:type) { create(:ticket_type, event: event, name: 'General') }
  let!(:groups) { (1..2).map { |n| event.ticket_groups.create!(name: "Room #{n}", position: n) } }

  def paid_ticket(name)
    create(:ticket, event: event, ticket_type: type, status: :purchased, payment_status: :paid,
                    attendee_name: name, attendee_email: "#{name}@example.com")
  end

  it 'puts a newly paid ticket into the smallest group, keeping groups balanced' do
    tickets = %w[a b c d].map { |n| paid_ticket(n) }

    expect(tickets.map { |t| t.reload.ticket_group_id }).to all(be_present)
    expect(groups.map { |g| g.tickets.count }).to eq([2, 2])
  end

  it 'places a ticket when it becomes paid later' do
    ticket = create(:ticket, event: event, ticket_type: type, status: :purchased, payment_status: :pending,
                             attendee_name: 'late', attendee_email: 'late@example.com')
    expect(ticket.reload.ticket_group_id).to be_nil

    ticket.update!(payment_status: :paid)
    expect(ticket.reload.ticket_group_id).to be_present
  end

  it 'does nothing when the switch is off' do
    event.update!(auto_assign_ticket_groups: false)
    expect(paid_ticket('x').reload.ticket_group_id).to be_nil
  end

  it 'does nothing when the whole groups feature is off' do
    event.update!(use_ticket_groups: false)
    expect(paid_ticket('y').reload.ticket_group_id).to be_nil
  end

  it 'never blocks the ticket from saving if grouping fails' do
    allow(TicketGroupAssigner).to receive(:assign_new!).and_raise(StandardError, 'boom')
    expect { paid_ticket('z') }.not_to raise_error
  end
end
