require "rails_helper"

RSpec.describe EventSeatingGroupMember, type: :model do
  describe "validations" do
    let(:event) { create(:event) }
    let(:plan) { create(:plan, event: event) }
    let(:group) { create(:event_seating_group, event: event, plan: plan) }

    it "is valid for ticket participant" do
      ticket = create(:ticket, event: event)
      member = described_class.new(event_seating_group: group, participant: ticket)
      expect(member).to be_valid
    end

    it "is valid for visitor participant" do
      visitor = create(:visitor, event: event)
      member = described_class.new(event_seating_group: group, participant: visitor)
      expect(member).to be_valid
    end

    it "enforces unique participant membership across groups" do
      ticket = create(:ticket, event: event)
      create(:event_seating_group_member, event_seating_group: group, participant: ticket)
      other_group = create(:event_seating_group, event: event, plan: plan, name: "Other")

      duplicate = described_class.new(event_seating_group: other_group, participant: ticket)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:participant_id]).to be_present
    end
  end
end
