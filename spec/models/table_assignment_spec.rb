require 'rails_helper'

RSpec.describe TableAssignment, type: :model do
  describe 'associations' do
    it { should belong_to(:ticket).optional }
    it { should belong_to(:visitor).optional }
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

    it "rejects assignments when table capacity is full" do
      plan = create(:plan)
      table = create(:plan_object, :table, plan: plan, capacity: 1)
      create(:table_assignment, ticket: create(:ticket, event: plan.event), plan_object: table)

      new_assignment = described_class.new(
        ticket: create(:ticket, event: plan.event),
        plan_object: table
      )

      expect(new_assignment).not_to be_valid
      expect(new_assignment.errors[:base].join).to include("Insufficient space")
    end

    it "allows assignment when there is remaining capacity" do
      plan = create(:plan)
      table = create(:plan_object, :table, plan: plan, capacity: 2)
      create(:table_assignment, ticket: create(:ticket, event: plan.event), plan_object: table)

      assignment = described_class.new(
        ticket: create(:ticket, event: plan.event),
        plan_object: table
      )
      expect(assignment).to be_valid
    end

    it "persists notes" do
      assignment = create(:table_assignment, notes: "Near stage")
      expect(assignment.reload.notes).to eq("Near stage")
    end
  end
end
