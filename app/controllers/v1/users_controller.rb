module V1
	class UsersController < ApplicationController
		# Skip JWT check for registration
		skip_before_action :authenticate_request!, only: [:create]

		# Create action will only be used for registration

		def create
			# Default role is participant as set in the model/migration
			@user = User.new(user_params)

			# Authorize the action using the UserPolicy
			authorize @user

			if @user.save
				# Automatically log the user in after successful registration
				token = JsonWebToken.encode(user_id: @user.id)
				render json: {
					user: @user,
					token: token
				}, status: :created
			else
				render json: { erorrs: @user.errors.full_messages }, status: :unprocessable_entity
			end
		end

		private

		def user_params
			params.expect(user: [:email, :password, :password_confirmation, :full_name, :phone])
		end
	end
end