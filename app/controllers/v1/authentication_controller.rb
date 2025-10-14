module V1
	class AuthenticationController < ApplicationController
		# Skip JWT check for login
		skip_before_action :authenticate_request!, only: [:login]

		def login
			@user = User.find_by(email: params[:email])

			# Authenticate user using bcrypt's has_secure_password
			if @user&.authenticate(params[:password])
				# Issue JWT
				token = JsonWebToken.encode(user_id: @user.id)
				render json: {
					user: @user,
					token: token
				}, status: :ok
			else
				# Raise unauthorized error if crendentials are incorrect
				raise CustomError::Unauthorized.new('Invalid email or password')
			end
		end
	end
end