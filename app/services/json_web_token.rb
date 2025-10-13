class JsonWebToken
	# The secret key for encoding/decoding the token
	SECRET_KEY = Rails.application.credentials.secret_key_base

	def self.encode(payload, exp = 24.hours.from_now)
		# Set expiration time
		payload[:exp] = exp.to_i

		# Sign token with application secret
		JWT.encode(payload, SECRET_KEY)
	end

	def self.decode(token)
		# Decode token. JWT.decode raises JWT::DecodeError on failure (e.g., token expired)
		decoded = JWT.decode(token, SECRET_KEY)[0]
		HasWithIndifferentAccess.new decoded

	rescue JWT::DecodeError => e
		# Re-raise as Unauthorized to be caught by the ApplicationController
		raise CustomError:Unauthorized.new(e.message)
	end
end