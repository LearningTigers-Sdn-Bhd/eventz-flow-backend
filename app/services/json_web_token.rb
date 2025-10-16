require 'jwt'
# Required to use HashWithIndifferentAccess in a service object outside a controller context
require 'active_support/core_ext/hash/indifferent_access' 

class JsonWebToken
    # Use Rails.application.secret_key_base which is the standard Rails way
    # and is automatically loaded from credentials.
    SECRET_KEY = Rails.application.secret_key_base 

    # Class method to encode a payload into a JWT token
    # Sets expiration (exp) claim automatically
    def self.encode(payload, exp = 15.minutes.from_now)
        # Use deep dup to ensure the original payload isn't modified
        payload_with_exp = payload.dup
        payload_with_exp[:exp] = exp.to_i 
        
        # Sign token with application secret
        JWT.encode(payload_with_exp, SECRET_KEY, 'HS256')
    end

    # Class method to decode a JWT token
    def self.decode(token)
        # JWT.decode returns an array of [payload, header]. We only need the payload ([0])
        decoded = JWT.decode(token, SECRET_KEY)[0]
        
        # FIX: Corrected the typo and used the full namespace for the constant
        ActiveSupport::HashWithIndifferentAccess.new(decoded)

    rescue JWT::DecodeError => e
        # FIX: Explicitly reference the exception class with the scope operator
        # This re-raises an unauthorized error for the ApplicationController to handle
        raise CustomError::Unauthorized, e.message
    end
end