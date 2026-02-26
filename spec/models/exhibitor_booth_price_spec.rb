require "rails_helper"

RSpec.describe ExhibitorBoothPrice, type: :model do
  describe "associations" do
    it { should belong_to(:event) }
    it { should have_many(:exhibitor_kits) }
  end

  describe "validations" do
    subject(:booth_price) { build(:exhibitor_booth_price) }

    it { should validate_presence_of(:booth_type) }
    it { should validate_presence_of(:label) }
    it { should validate_presence_of(:price) }

    it "validates uniqueness of label scoped to event and booth_type" do
      event = create(:event)
      create(:exhibitor_booth_price, event: event, booth_type: "shell_scheme", label: "Malaysian")

      duplicate = build(:exhibitor_booth_price, event: event, booth_type: "shell_scheme", label: "Malaysian")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:label]).to include("has already been taken")
    end
  end
end
