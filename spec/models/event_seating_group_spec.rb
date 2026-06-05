require "rails_helper"

RSpec.describe EventSeatingGroup, type: :model do
  describe "validations" do
    it "is valid with plan_only scope and plan_id" do
      event = create(:event)
      plan = create(:plan, event: event)
      group = build(:event_seating_group, event: event, plan: plan, scope: :plan_only)
      expect(group).to be_valid
    end

    it "requires a plan for plan_only scope" do
      group = build(:event_seating_group, scope: :plan_only, plan: nil)
      expect(group).not_to be_valid
      expect(group.errors[:plan]).to include("must be present for plan-only groups")
    end

    it "clears plan for event_level scope" do
      group = build(:event_seating_group, :event_level)
      group.valid?
      expect(group.plan_id).to be_nil
      expect(group).to be_valid
    end

    it "requires name" do
      group = build(:event_seating_group, name: nil)
      expect(group).not_to be_valid
    end
  end
end
