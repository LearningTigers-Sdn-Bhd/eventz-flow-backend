require 'rails_helper'

RSpec.describe TableAssignment, type: :model do
  describe 'associations' do
    it { should belong_to(:ticket) }
    it { should belong_to(:plan_object) }
  end

  describe 'validations' do
    subject { create(:table_assignment) }
    it { should validate_uniqueness_of(:ticket_id).with_message("is already assigned to a table") }

    it 'validates that plan_object is a table' do
      table = create(:plan_object, object_type: :table)
      wall = create(:plan_object, object_type: :wall)
      ticket = create(:ticket)

      assignment = TableAssignment.new(ticket: ticket, plan_object: wall)
      expect(assignment).not_to be_valid
      expect(assignment.errors[:plan_object]).to include("must be a table")

      assignment.plan_object = table
      expect(assignment).to be_valid
    end
  end
end