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
      let!(:group1) { create_list(:ticket, 5, event: event, transaction_id: 'tx_1') }
      let!(:group2) { create_list(:ticket, 2, event: event, transaction_id: 'tx_2') }

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
      let!(:group_huge) { create_list(:ticket, 6, event: event, transaction_id: 'tx_huge') }

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
  end
end
