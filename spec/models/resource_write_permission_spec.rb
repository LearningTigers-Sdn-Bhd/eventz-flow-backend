# spec/models/resource_write_permission_spec.rb
require 'rails_helper'

RSpec.describe ResourceWritePermission, type: :model do
  # Create a user first to associate the permission with
  let(:user) { create(:user) }

  subject { build(:resource_write_permission, user: user) }

  describe 'validations' do
    it { should validate_uniqueness_of(:user_id) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(base: 0, partnership: 1) }
  end
end
