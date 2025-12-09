# spec/models/event_assignment_spec.rb
require 'rails_helper'

RSpec.describe EventAssignment, type: :model do
  # --- Setup ---
  let(:event) { create(:event) }
  let(:vendor) { create(:user, :member) }
  let(:admin) { create(:user, :member) }

  # --- Associations ---
  describe 'Associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:user) }
  end

  # --- Validations ---
  describe 'Validations' do
    subject { build(:event_assignment, event: event, user: vendor, role: :event_admin) }

    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:event_id) }
  end

  # --- Callbacks ---
  # Note: Vendor profile creation has been moved to GroupAffiliate callback
  # EventAssignment no longer creates vendor profiles
end
