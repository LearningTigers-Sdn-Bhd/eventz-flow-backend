require 'rails_helper'

RSpec.describe PlanObject, type: :model do
  describe 'associations' do
    it { should belong_to(:plan) }
    it { should have_many(:table_assignments).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:object_type).with_values(table: 0, wall: 1, door: 2, stage: 3, label: 4).with_prefix }
  end

  describe 'validations' do
    it { should validate_presence_of(:x) }
    it { should validate_presence_of(:y) }
    it { should validate_numericality_of(:width).is_greater_than(0).allow_nil }
    it { should validate_numericality_of(:height).is_greater_than(0).allow_nil }
    
    context 'when object is a table' do
      subject { build(:plan_object, object_type: :table) }
      it { should validate_numericality_of(:capacity).is_greater_than_or_equal_to(0) }
    end
    
    context 'when object is not a table' do
      subject { build(:plan_object, object_type: :wall) }
      it { should_not validate_numericality_of(:capacity) }
    end
  end
end