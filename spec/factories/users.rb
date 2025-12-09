# spec/factories/users.rb

FactoryBot.define do
	factory :user do
		email { Faker::Internet.unique.email }
		password { "secure_password123" }
		password_confirmation { "secure_password123" }
		full_name { Faker::Name.name }
		phone { Faker::PhoneNumber.phone_number }
		email_verified_at { Time.current }

		# Default role is the base user role
		role { :member }

		# Trait for admin users (highest level, equivalent to org_owner for policy purposes)
		trait :admin do
			role { :org_owner } # Assuming 'org_owner' acts as admin for policies
		end

		# Trait for organizer users
		trait :organizer do
			role { :organizer }
		end

		# Trait for contractor users
		trait :exhibition_contractor do
			role { :exhibition_contractor }
			transient do
				with_profile { true }
			end
			after(:create) do |user, evaluator|
				create(:exhibition_contractor_profile, user: user) if evaluator.with_profile
			end
		end

		# Trait for exhibitor users
		trait :exhibitor do
			role { :exhibitor }
		end
		
		# created_by is optional (NULL for self-registered users)
		created_by { nil }

		# Trait for unverified users
		trait :unverified do
			email_verified_at { nil }
		end

		# --- Role-Specific Factories (for convenience, now as traits) ---

		# 1. Highest Authority (System Owner)
		trait :org_owner do
			role { :org_owner }
			# Override the email to make the platform owner easily identifiable
			email { "org_owner_#{Faker::Number.unique.number(digits: 5)}@platform.com" }
		end

		# 2. Organizer User
		# factory :organizer_user, parent: :user do # Replaced by :organizer trait
		# 	role { :organizer }
		# end

		# 3. Standard User/Participant
		# Renamed from participant_user to explicitly show the base role
		# factory :member_user, parent: :user do # Redundant with default role { :member }
		# 	role { :member }
		# end

		# factory :vendor_user, parent: :user do # Covered by :vendor trait if needed
		# 	role { :vendor }
		# end

		# factory :staff_user, parent: :user do # Covered by :staff_member trait if needed
		# 	# This creates a generic user who will be assigned the EventTeamMember role in the tests.
		# end

		# --- Role Traits (preferred way to create users with specific roles) ---
		trait :org_owner do
			role { :org_owner }
		end

		trait :organizer do
			role { :organizer }
		end

		trait :member do
			role { :member }
		end

		trait :vendor do
			role { :vendor }
		end

		trait :exhibitor do
			role { :exhibitor }
		end

		trait :exhibition_contractor do
			role { :exhibition_contractor }
		end

		# Trait for users created by another user (e.g., organizer creating members)
		trait :created_by_organizer do
			created_by { association :user, factory: :organizer } # Use the new trait
		end

		trait :staff_member do
			role { :member }
		end

		# DEPRECATED/Removed Factories:
		# The old 'admin_user', 'superadmin', 'participant_user', and 'team_member_user'
		# factories are no longer used, as their logic is covered by :org_owner, :organizer_user,
		# and the default :user/:member_user factory.
	end
end
