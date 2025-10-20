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
        payload[:exp] = exp.to_i
        JWT.encode(payload, SECRET_KEY, 'HS256')
    end

    # Class method to decode a JWT token
    def self.decode(token)
        # JWT.decode returns an array of [payload, header]. We only need the payload ([0])
        decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
        HashWithIndifferentAccess.new(decoded[0])
    rescue JWT::ExpiredSignature
        raise CustomError::Unauthorized.new('Token has expired')
    rescue JWT::DecodeError
        raise CustomError::Unauthorized.new('Invalid token')
    end
end
