# app/services/authentication_service.rb
require 'digest/sha2'

class AuthenticationService
    
    # Generates a cryptographically secure, random token string
    def self.generate_secure_token
        SecureRandom.hex(32)
    end

    # Hashes a token using SHA256 for secure database storage
    def self.hash_token(token)
        Digest::SHA256.hexdigest(token)
    end
end