class UserPolicy < ApplicationPolicy
	# Note: The 'user' here is the @current_user (the logged-in user)
	# The 'record' here is the User instance being acted upon (or User class)

	def index?
		# Only superadmins can view a list of all users
		user.is_superadmin?
	end

	def show?
		# A user can view their own profile, or an admin can view any profile
		user.is_superadmin? || record == user
	end

	def create?
		# Anyone can register (create a new User record)
		true
	end

	def update?
		# A user can update their own profile, or a superadmin can update any profile
		user.is_superadmin? || record == user
	end

	def destroy?
		# Only superadmins can delete users
		user.is_superadmin?
	end
end