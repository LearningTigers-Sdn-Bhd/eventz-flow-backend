# frozen_string_literal: true
require 'jwt'
require 'digest'

class JwtService
  SECRET_KEY = ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
  ALGORITHM = 'HS256'
  ACCESS_TOKEN_EXPIRATION = 15.minutes
  REFRESH_TOKEN_EXPIRATION = 30.days

  class << self
    def encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now)
      payload[:exp] = exp.to_i
      payload[:iat] = Time.now.to_i
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    rescue => e
      raise CustomError::Unauthorized.new("Failed to encode token: #{e.message}")
    end

    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, {
        algorithm: ALGORITHM,
        verify_expiration: true,
        verify_iat: true
      })
      ActiveSupport::HashWithIndifferentAccess.new(decoded[0])
    rescue JWT::ExpiredSignature
      raise CustomError::Unauthorized.new('Token has expired')
    rescue JWT::DecodeError
      raise CustomError::Unauthorized.new('Invalid token')
    rescue => e
      raise CustomError::Unauthorized.new("Failed to decode token: #{e.message}")
    end

    def generate_tokens(user, request = nil, existing_session = nil)
      # 1. Keep JTI stable for an existing session; only refresh credentials rotate.
      session_jti = existing_session&.jti || SecureRandom.uuid

      # 2. Prepare payloads
      access_payload = {
        user_id: user.id,
        jti: session_jti, # Session-specific JTI
        role: user.role
      }

      refresh_payload = {
        user_id: user.id,
        jti: session_jti, # Same JTI links access and refresh tokens
        type: 'refresh'
      }

      # 3. Encode tokens
      access_token_exp = ACCESS_TOKEN_EXPIRATION.from_now
      access_token = encode(access_payload, access_token_exp)
      
      refresh_token_exp = REFRESH_TOKEN_EXPIRATION.from_now
      refresh_token = encode(refresh_payload, refresh_token_exp)

      # 4. Create or Update Session
      refresh_hash = hash_token(refresh_token)
      
      if existing_session
        # Rotation: Update existing session
        existing_session.update!(
          refresh_token_hash: refresh_hash,
          expires_at: refresh_token_exp,
          last_used_at: Time.current,
          ip_address: request&.remote_ip,
          user_agent: request&.user_agent
        )
        session_id = existing_session.id
      else
        # New Session
        session = create_session(user, session_jti, refresh_hash, refresh_token_exp, request)
        session_id = session.id
      end

      { 
        access_token: access_token, 
        refresh_token: refresh_token, 
        expires_at: access_token_exp,
        session_id: session_id
      }
    end

    def refresh_access_token(refresh_token, request = nil)
      # Decode without verification first to check type? No, decode verifies signature.
      payload = decode(refresh_token)
      raise CustomError::Unauthorized.new('Invalid refresh token') unless payload[:type] == 'refresh'

      # Find session by hashed refresh token
      refresh_hash = hash_token(refresh_token)
      session = UserSession.find_by(refresh_token_hash: refresh_hash)

      # Validate session
      unless session && session.active?
        if session && session.revoked?
            Rails.logger.warn "Security: Revoked refresh token reused for User #{session.user_id}"
        end
        raise CustomError::Unauthorized.new('Invalid or expired session')
      end

      # Validate User
      user = session.user
      raise CustomError::Unauthorized.new('User not found') unless user

      # Rotate tokens (updates session)
      tokens = generate_tokens(user, request, session)
      tokens[:user] = user
      tokens
    end

    def decode_token(token)
      decode(token)
    end
    
    # Helper methods
    
    def hash_token(token)
      Digest::SHA256.hexdigest(token)
    end

    private

    def create_session(user, jti, refresh_hash, expires_at, request)
      UserSession.create!(
        user: user,
        jti: jti,
        refresh_token_hash: refresh_hash,
        expires_at: expires_at,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent,
        device_name: extract_device_name(request),
        last_used_at: Time.current
      )
    end

    def extract_device_name(request)
      return nil unless request
      
      ua = request.user_agent
      return "Unknown Device" unless ua
      
      # Basic detection
      if ua.match?(/Mobile|Android|iPhone|iPad|iPod/)
        "Mobile Device"
      elsif ua.match?(/Windows|Macintosh|Linux/)
        "Desktop"
      else
        "Unknown Device"
      end
    end
  end
end
