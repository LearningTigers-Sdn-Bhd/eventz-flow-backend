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
		
		# created_by is optional (NULL for self-registered users)
		created_by { nil }

		# Trait for unverified users
		trait :unverified do
			email_verified_at { nil }
		end

		# --- Role-Specific Factories (for convenience) ---

		# 1. Highest Authority (System Owner)
		factory :org_owner, parent: :user do
			role { :org_owner }
			# Override the email to make the platform owner easily identifiable
			email { "org_owner_#{Faker::Number.unique.number(digits: 5)}@platform.com" }
		end

		# 2. Organizer User
		factory :organizer_user, parent: :user do
			role { :organizer }
		end

		# 3. Standard User/Participant
		# Renamed from participant_user to explicitly show the base role
		factory :member_user, parent: :user do
			role { :member }
		end

		factory :vendor_user, parent: :user do
			role { :vendor }
		end

		factory :staff_user, parent: :user do
			# This creates a generic user who will be assigned the EventTeamMember role in the tests.
		end

		# Trait for users created by another user (e.g., organizer creating members)
		trait :created_by_organizer do
			created_by { association :organizer_user }
		end

		# DEPRECATED/Removed Factories:
		# The old 'admin_user', 'superadmin', 'participant_user', and 'team_member_user'
		# factories are no longer used, as their logic is covered by :org_owner, :organizer_user,
		# and the default :user/:member_user factory.
	end
end
