require "rails_helper"

RSpec.describe EventHall, type: :model do
  it "is valid with a name and event" do
    expect(build(:event_hall)).to be_valid
  end

  it "requires a name" do
    expect(build(:event_hall, name: nil)).not_to be_valid
  end

  it "keeps names unique within an event only" do
    hall = create(:event_hall, name: "Hall A")
    expect(build(:event_hall, event: hall.event, name: "Hall A")).not_to be_valid
    expect(build(:event_hall, name: "Hall A")).to be_valid
  end

  it "is destroyed with its event" do
    hall = create(:event_hall)
    expect { hall.event.destroy }.to change(described_class, :count).by(-1)
  end
end
