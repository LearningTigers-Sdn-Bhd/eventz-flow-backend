require 'rails_helper'

RSpec.describe AutoDistributeService do
  let(:event) { create(:event) }
  let(:plan) { create(:plan, event: event) }
  
  # Tables
  let!(:table_large) { create(:plan_object, :table, plan: plan, capacity: 5, z_index: 1) }
  let!(:table_small) { create(:plan_object, :table, plan: plan, capacity: 3, z_index: 2) }

  subject { described_class.new(plan) }

  describe '#call' do
    context 'when perfect fit is possible' do
      let!(:group1) { create_list(:ticket, 5, event: event, registered_by_email: 'tx_1@example.com') }
      let!(:group2) { create_list(:ticket, 2, event: event, registered_by_email: 'tx_2@example.com') }

      it 'assigns groups to tables fitting them completely' do
        subject.call
        
        expect(table_large.table_assignments.count).to eq(5)
        # Check that assignments belong to group1
        expect(table_large.table_assignments.map(&:ticket)).to match_array(group1)
        
        expect(table_small.table_assignments.count).to eq(2)
        expect(table_small.table_assignments.map(&:ticket)).to match_array(group2)
      end
    end

    context 'when splitting is required' do
      let!(:group_huge) { create_list(:ticket, 6, event: event, registered_by_email: 'tx_huge@example.com') }

      it 'splits the group across available tables' do
        # Total capacity: 5 + 3 = 8. Group: 6.
        # It should fill table_large (5) then put remainder in table_small
        
        subject.call
        
        total_assigned = TableAssignment.count
        expect(total_assigned).to eq(6)
        
        expect(table_large.table_assignments.count).to eq(5)
        expect(table_small.table_assignments.count).to eq(1)
      end
    end

    context "with explicit seating groups" do
      let!(:ticket1) { create(:ticket, event: event) }
      let!(:ticket2) { create(:ticket, event: event) }
      let!(:visitor1) { create(:visitor, event: event) }
      let!(:seating_group) { create(:event_seating_group, event: event, plan: plan, name: "VIP Block") }

      before do
        create(:event_seating_group_member, event_seating_group: seating_group, participant: ticket1)
        create(:event_seating_group_member, event_seating_group: seating_group, participant: ticket2)
        create(:event_seating_group_member, event_seating_group: seating_group, participant: visitor1)
      end

      it "keeps explicit groups intact when table can fit" do
        result = subject.call
        assigned_ids = TableAssignment.where(ticket_id: [ticket1.id, ticket2.id]).pluck(:plan_object_id).uniq
        visitor_assignment = TableAssignment.find_by(visitor_id: visitor1.id)

        expect(assigned_ids.size).to eq(1)
        expect(visitor_assignment).to be_present
        expect(visitor_assignment.plan_object_id).to eq(assigned_ids.first)
        expect(result[:skipped_groups]).to be_empty
      end

      it "skips explicit groups when no full-fit table exists" do
        table_large.update!(capacity: 2)
        table_small.update!(capacity: 2)

        result = subject.call
        expect(result[:skipped_groups].size).to eq(1)
        skip = result[:skipped_groups].first
        expect(skip[:group_id]).to eq(seating_group.id)
        expect(skip[:needed_to_fit]).to be >= 1
      end
    end
  end
end
