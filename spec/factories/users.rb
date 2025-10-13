FactoryBot.define do 
	factory :user do
		email { Faker::Internet.unique.email }
		password { "secure_password123" }
		password_confirmation { "secure_password123" }
		full_name { Faker::Name.name }
		phone { Faker::PhoneNumber.phone_number } 

		# Default role is participant
		role { :participant }

		# --- Role-Specific Factories (for convenience) ---
		factory :superadmin, parent: :user do
			role { :superadmin }
			#Override the email to make Superadmin easily identifiable
			email { "superadmin_#{Faker::Number.unique.number(digits: 5)}@eventzflow.com" }
		end

		factory :admin_user, parent: :user do
			role { :admin }
		end

		factory :team_member_user, parent: :user do
			role { :team_member }
		end

		factory :participant_user, parent: :user do
			role { :participant }
		end
	end
end