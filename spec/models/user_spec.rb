require 'rails_helper'

RSpec.describe User, type: :model do
	describe 'Validations' do
		# Test 1: Presence and Uniqueness of Email
		it { is_expected.to validate_presence_of(:email) }

		# Must first create a user instance for the uniqueness check to work
		describe 'Uniqueness of Email' do
			let!(:existing_user) { create(:user) }
			it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
		end

		# Test 2: Secure Password
		it { is_expected.to have_secure_password }

		# Test 3: Role Definition
		it 'is valid with a defined role' do
			# Test all defined roles from the enum
			%i[org_owner organizer member vendor].each do |role|
				user = build(:user, role: role)
				expect(user).to be_valid
			end
		end

		# Test 4: Presence of Full Name
		it { is_expected.to validate_presence_of(:full_name) }

		# Test 5: Status Definition
		it 'is valid with a defined status' do
			# Test all defined statuses from the enum
			%i[active inactive].each do |status|
				user = build(:user, status: status)
				expect(user).to be_valid
			end
		end

		# Test 6: Default Status
		it 'defaults to active status for new users' do
			user = User.new(email: 'test@example.com', full_name: 'Test User', password: 'password123')
			expect(user.status).to eq('active')
		end
	end

	# Description: Test the crucial RBAC relationships defined on the model.
	describe 'Associations and RBAC Scopes' do
		# --- REFACTORED ASSOCIATIONS ---
		# Test 5: Relationships (Using the new unified EventAssignment model)
		it { is_expected.to have_many(:event_assignments).dependent(:destroy) }
		it { is_expected.to have_many(:assigned_events).through(:event_assignments).source(:event) }
		it { is_expected.to have_many(:event_location_members).dependent(:destroy) }
		it { is_expected.to have_many(:assigned_locations).through(:event_location_members).source(:event_location) }
		it { is_expected.to have_many(:assigned_event_admins).dependent(:destroy).class_name('EventAssignment') }
		# ------------------------------

		# Test 6: Role Helper Methods
		# NOTE: Using the correct factory names as defined in spec/factories/users.rb
		let(:org_owner_user) { create(:org_owner) }
		let(:organizer_user) { create(:organizer_user) }
		let(:member_user) { create(:member_user) }
		let(:vendor_user) { create(:vendor_user) }

		it 'correctly identifies a Organization owner' do
			expect(org_owner_user.org_owner?).to be true
			expect(organizer_user.org_owner?).to be false
		end


		it 'correctly identifies an Organizer (including Organization owner)' do
			expect(org_owner_user.is_organizer?).to be true
			expect(organizer_user.is_organizer?).to be true
			expect(member_user.is_organizer?).to be false
		end

		it 'correctly identifies a Member' do
			expect(member_user.is_member?).to be true
			expect(organizer_user.is_member?).to be false
		end

		it 'correctly identifies staff members' do
			expect(org_owner_user.is_staff?).to be true
			expect(organizer_user.is_staff?).to be true
			expect(member_user.is_staff?).to be true
			expect(vendor_user.is_staff?).to be false
		end

		it 'correctly identifies vendors' do
			expect(vendor_user.is_vendor?).to be true
			expect(member_user.is_vendor?).to be false
		end
	end
end