# frozen_string_literal: true
require 'jwt'

class JwtService
  # Use Rails.application.secret_key_base which is the standard Rails way
  # and is automatically loaded from credentials.
  SECRET_KEY = ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
  ALGORITHM = 'HS256'

  class << self
    # Encodes a payload into a JWT token with automatic expiration
    #
    # @param payload [Hash] The data to encode in the token
    # @param exp [Time] Token expiration time (defaults to 15 minutes from now)
    # @return [String] The encoded JWT token
    # @raise [CustomError::Unauthorized] If encoding fails
    def encode(payload, exp = 30.minutes.from_now)
        payload[:exp] = exp.to_i
        payload[:iat] = Time.now.to_i

        JWT.encode(payload, SECRET_KEY, ALGORITHM)
    rescue => e
        raise CustomError::Unauthorized.new("Failed to encode token: #{e.message}")
    end

    # Decodes a JWT token and returns the payload
    #
    # @param token [String] The JWT token to decode
    # @return [HashWithIndifferentAccess] The decoded payload
    # @raise [CustomError::Unauthorized] If token is invalid, expired, or decoding fails
    def decode(token)
        decoded = JWT.decode(token, SECRET_KEY, true, {
                                algorithm: ALGORITHM,
                                verify_expiration: true,
                                verify_iat: true,
                            })

        ActiveSupport::HashWithIndifferentAccess.new(decoded[0])
    rescue JWT::ExpiredSignature
        raise CustomError::Unauthorized.new('Token has expired')
    rescue JWT::DecodeError
        raise CustomError::Unauthorized.new('Invalid token')
    rescue => e
        raise CustomError::Unauthorized.new("Failed to decode token: #{e.message}")
    end

    def generate_tokens(user)
        access_payload = {
            user_id: user.id,
            jti: user.jti,
            role: user.role,
        }

        refresh_payload = {
            user_id: user.id,
            jti: user.jti,
            type: 'refresh',
        }

        access_token = encode(access_payload)
        refresh_token = encode(refresh_payload, 7.days.from_now)
        expires_at = 30.minutes.from_now

        { access_token: access_token, refresh_token: refresh_token, expires_at: expires_at }
    end

    def refresh_access_token(refresh_token)
        payload = decode(refresh_token)

        raise CustomError::Unauthorized.new('Invalid refresh token') unless payload[:type] == 'refresh'

        user = User.find_by(id: payload[:user_id], jti: payload[:jti])
        raise CustomError::Unauthorized.new('User not found') unless user

        generate_tokens(user)
    end

    def decode_token(token)
        decode(token)
    end
  end
end
