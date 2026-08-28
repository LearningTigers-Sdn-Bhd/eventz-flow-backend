require 'rails_helper'

RSpec.describe TableAssignment, type: :model do
  describe 'associations' do
    it { should belong_to(:ticket).optional }
    it { should belong_to(:visitor).optional }
    it { should belong_to(:plan_object) }
  end

  describe 'validations' do
    subject { create(:table_assignment) }
    it { should validate_uniqueness_of(:ticket_id).with_message("is already assigned to a table in this plan") }

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

  describe "ticket custom field sync" do
    it "writes table_number when the ticket has no existing table number field" do
      table = create(:plan_object, :table, table_number: "12")
      ticket = create(:ticket, event: table.plan.event, custom_fields_data: { "special_diet" => "Vegan" })

      create(:table_assignment, ticket: ticket, plan_object: table)

      data = ticket.reload.custom_fields_data
      expect(data["table_number"]).to eq("12")
      expect(data).not_to have_key("_table_number")
    end

    it "merges into the event's existing table_number key instead of creating a second field" do
      table = create(:plan_object, :table, table_number: "21")
      ticket = create(:ticket, event: table.plan.event, custom_fields_data: { "table_number" => "-" })

      create(:table_assignment, ticket: ticket, plan_object: table)

      data = ticket.reload.custom_fields_data
      expect(data["table_number"]).to eq("21")
      expect(data.keys.count { |k| k.casecmp?("table_number") }).to eq(1)
    end

    it "removes a stray legacy _table_number key on sync" do
      table = create(:plan_object, :table, table_number: "5")
      ticket = create(:ticket, event: table.plan.event, custom_fields_data: { "_table_number" => "old" })

      create(:table_assignment, ticket: ticket, plan_object: table)

      data = ticket.reload.custom_fields_data
      expect(data["table_number"]).to eq("5")
      expect(data).not_to have_key("_table_number")
    end

    it "clears the same detected key when the assignment is removed" do
      table = create(:plan_object, :table, table_number: "8")
      ticket = create(:ticket, event: table.plan.event, custom_fields_data: { "Table_Number" => "old" })
      assignment = create(:table_assignment, ticket: ticket, plan_object: table)

      assignment.destroy

      data = ticket.reload.custom_fields_data
      expect(data).not_to have_key("Table_Number")
      expect(data).not_to have_key("table_number")
    end
  end
end
