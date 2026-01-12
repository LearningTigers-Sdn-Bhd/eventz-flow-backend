require 'rails_helper'

RSpec.describe EventSponsorshipTier, type: :model do
  describe 'Associations' do
    it { should belong_to(:group) }
    it { should belong_to(:event) }
    it { should have_many(:event_sponsorships).dependent(:nullify) }
  end

  describe 'Validations' do
    subject { create(:event_sponsorship_tier) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:event_id).case_insensitive }
  end

  describe 'Enums' do
    it { should define_enum_for(:sponsorship_type_default).with_values(monetary: 0, in_kind: 1, mixed: 2).with_prefix(:type) }
  end
end
