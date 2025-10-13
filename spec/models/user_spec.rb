require 'rails_helper'

RSpec.describe User, type: :model do
	# Description: We use shoulda-matchers to test standard Active Record functionality.
	# This makes the test readable and concise.

	describe 'Validations' do 
		# Test 1: Presence and Uniqueness of Email
		it { is_expected.to validate_presence_of(:email) }

		# We must first create a user instance for the uniqueness check to work
		describe 'Uniqueness of Email' do
			let!(:existing_user) { create(:user) }
			it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
		end

		# Test 2: Secure Password
		# has_secure_password ensures presence, we only check length/confirmation for robustness
		it { is_expected.to have_secure_password }

		# Test 3: Role Definition
		it 'is valid with a defined role' do 
			# Test all defined roles from the enum
			%i[superadmin admin team_member participant].each do |role|
				user = build(:user, role: role)
				expect(user).to be_valid
			end
		end

		# Description: Test the crucial RBAC relationships defined on the model.
		describe 'Associations and RBAC Scopes' do
			# Test 4: Relationships
			it { is_expected.to have_many(:event_admins).dependent(:destroy) }
			it { is_expected.to have_many(:assigned_events).through(:event_admins).source(:event) }
			it { is_expected.to have_many(:event_team_members).dependent(:destroy) }
			it { is_expected.to have_many(:events_managed).through(:event_team_members).source(:event) }

			# Test 5: Role Helper Methods
			let(:superadmin) { create(:superadmin) }
			let(:admin) { create(:admin_user) }
			let(:team_member) { create(:team_member_user) }
			let(:participant) { create(:participant_user) }

			it 'correctly identifies a Superadmin' do
				expect(superadmin.is_superadmin?).to be true
				expect(admin.is_superadmin?).to be false
			end

			it 'correctly identifies an Admin (including Superadmin)' do 
				expect(superadmin.is_admin?).to be true
				expect(admin.is_admin?).to be true
				expect(team_member.is_admin?).to be false
			end

			it 'correctly identifies a Team Member' do
			    expect(team_member.is_team_member?).to be true
			    expect(admin.is_team_member?).to be false
			end
		end
	end
end