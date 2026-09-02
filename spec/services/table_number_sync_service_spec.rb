require 'rails_helper'

RSpec.describe TableNumberSyncService do
  let(:event) { create(:event) }
  let(:plan) { create(:plan, event: event) }

  let!(:table_a) { create(:plan_object, :table, plan: plan, table_number: 'A1', capacity: 2) }
  let!(:table_b) { create(:plan_object, :table, plan: plan, table_number: 'B2', capacity: 1) }

  subject { described_class.new(plan) }

  def ticket_with_table_number(number)
    create(:ticket, event: event, custom_fields_data: { 'table_number' => number })
  end

  describe '#call' do
    it 'assigns tickets to the table matching their table_number field' do
      ticket = ticket_with_table_number('A1')

      result = subject.call

      expect(result[:synced_count]).to eq(1)
      expect(result[:warnings]).to be_empty
      expect(ticket.reload.table_assignments.first.plan_object).to eq(table_a)
    end

    it 'matches case-insensitively and ignores surrounding whitespace' do
      ticket = ticket_with_table_number(' a1 ')

      subject.call

      expect(ticket.reload.table_assignments.first.plan_object).to eq(table_a)
    end

    it 'ignores tickets without a table_number value' do
      create(:ticket, event: event, custom_fields_data: {})

      result = subject.call

      expect(result[:synced_count]).to eq(0)
      expect(result[:warnings]).to be_empty
    end

    it 'warns when no table matches the given table_number' do
      ticket = ticket_with_table_number('Z9')

      result = subject.call

      expect(result[:synced_count]).to eq(0)
      expect(result[:warnings]).to contain_exactly(
        hash_including(ticket_id: ticket.id, table_number: 'Z9', reason: 'no_matching_table')
      )
    end

    it 'warns when the matching table is already full' do
      create(:ticket, event: event).table_assignments.create!(plan_object: table_b)
      overflow_ticket = ticket_with_table_number('B2')

      result = subject.call

      expect(result[:synced_count]).to eq(0)
      expect(result[:warnings].first[:ticket_id]).to eq(overflow_ticket.id)
      expect(result[:warnings].first[:reason]).to match(/insufficient space/i)
    end

    it 'moves an existing assignment when the table_number field points to a different table' do
      ticket = ticket_with_table_number('B2')
      ticket.table_assignments.create!(plan_object: table_a)

      result = subject.call

      expect(result[:synced_count]).to eq(1)
      expect(ticket.reload.table_assignments.count).to eq(1)
      expect(ticket.table_assignments.first.plan_object).to eq(table_b)
    end

    it 'is idempotent when re-run for an already-synced ticket' do
      ticket = ticket_with_table_number('A1')
      subject.call

      result = described_class.new(plan).call

      expect(result[:synced_count]).to eq(1)
      expect(ticket.reload.table_assignments.count).to eq(1)
    end

    it 'reads from a custom field_key when given one instead of the default' do
      ticket = create(:ticket, event: event, custom_fields_data: { 'seat_table' => 'A1' })

      result = described_class.new(plan, field_key: 'seat_table').call

      expect(result[:synced_count]).to eq(1)
      expect(result[:field_key]).to eq('seat_table')
      expect(ticket.reload.table_assignments.first.plan_object).to eq(table_a)
    end
  end

  describe '.recommend_field_key' do
    it 'prefers the conventional table_number key when present' do
      labels = { 'company' => 'Company', 'table_number' => 'Table Number' }

      expect(described_class.recommend_field_key(labels)).to eq('table_number')
    end

    it 'falls back to a key that looks like a table number field' do
      labels = { 'company' => 'Company', 'seat_table_no' => 'Seat Table No' }

      expect(described_class.recommend_field_key(labels)).to eq('seat_table_no')
    end

    it 'returns nil when nothing matches' do
      labels = { 'company' => 'Company', 'dietary' => 'Dietary Preference' }

      expect(described_class.recommend_field_key(labels)).to be_nil
    end
  end
end
