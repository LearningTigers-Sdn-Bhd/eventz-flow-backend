require 'rails_helper'

RSpec.describe Plan, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should have_many(:plan_objects).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:plan) }
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:canvas_width).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:canvas_height).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe 'secure token' do
    it 'generates a share_token on creation' do
      plan = create(:plan)
      expect(plan.share_token).to be_present
    end
  end
end