require 'rails_helper'

RSpec.describe ExhibitionContractorProfile, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:event_exhibition_contractors).dependent(:destroy) }
    it { is_expected.to have_many(:events).through(:event_exhibition_contractors) }
  end

  describe 'Validations' do
    subject { create(:exhibition_contractor_profile) }

    it { is_expected.to validate_uniqueness_of(:user_id).with_message('already has a profile') }
    it { is_expected.to allow_value("test@example.com").for(:contact_email) }
    it { is_expected.to allow_value("").for(:contact_email) }
    it { is_expected.to_not allow_value("invalid-email").for(:contact_email) }

    describe 'user role validation' do
      let(:exhibition_contractor_user) { create(:user, :exhibition_contractor, with_profile: false) }
      let(:member_user) { create(:user, :member) }

      it 'is valid when user has exhibition_contractor role' do
        profile = build(:exhibition_contractor_profile, user: exhibition_contractor_user)
        expect(profile).to be_valid
      end

      it 'is invalid when user does not have exhibition_contractor role' do
        profile = build(:exhibition_contractor_profile, user: member_user)
        expect(profile).not_to be_valid
        expect(profile.errors[:user]).to include('must have exhibition_contractor role')
      end
    end
  end
end