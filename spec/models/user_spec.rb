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
			%i[org_owner organizer member vendor exhibitor exhibition_contractor].each do |role|
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
		it { is_expected.to have_one(:exhibition_contractor_profile).dependent(:destroy) } # New association test
		# ------------------------------

		# Test 6: Role Helper Methods
		# NOTE: Using the correct factory names as defined in spec/factories/users.rb
		let(:org_owner_user) { create(:user, :org_owner) }
		let(:organizer_user) { create(:user, :organizer) }
		let(:member_user) { create(:user, :member) }
		let(:vendor_user) { create(:user, :vendor) }
    context "correctly identifies exhibition contractors" do
      let(:user) { create(:user, :member) }
      let(:exhibition_contractor_user) { create(:user, :exhibition_contractor, with_profile: false) } # New user for testing
      let(:event) { create(:event) }
      let!(:exhibition_contractor_profile) { create(:exhibition_contractor_profile, user: exhibition_contractor_user) }


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

		it 'correctly identifies vendors' do
			expect(vendor_user.is_vendor?).to be true
			expect(member_user.is_vendor?).to be false
		end

		it 'correctly identifies exhibition contractors' do
			expect(exhibition_contractor_user.is_exhibition_contractor?).to be true
			expect(member_user.is_exhibition_contractor?).to be false
		end

		describe '#only_business_matching_admin?' do
			let(:bm_admin_user) { create(:user, :member) }
			let(:event) { create(:event) }

			it 'is true for a member whose only standing is business_matching_admin' do
				create(:event_assignment, event: event, user: bm_admin_user, role: :business_matching_admin)
				expect(bm_admin_user.only_business_matching_admin?).to be true
				expect(bm_admin_user.business_matching_admin_event_ids).to eq([event.id])
			end

			it 'is false for an org owner even with a business_matching_admin assignment' do
				create(:event_assignment, event: event, user: org_owner_user, role: :business_matching_admin)
				expect(org_owner_user.only_business_matching_admin?).to be false
			end

			it 'is false if the user also holds event_admin on any event' do
				create(:event_assignment, event: event, user: bm_admin_user, role: :business_matching_admin)
				other_event = create(:event)
				create(:event_assignment, event: other_event, user: bm_admin_user, role: :event_admin)
				expect(bm_admin_user.only_business_matching_admin?).to be false
			end

			it 'is false with no business_matching_admin assignment at all' do
				expect(member_user.only_business_matching_admin?).to be false
			end
		end
	end
end
end
