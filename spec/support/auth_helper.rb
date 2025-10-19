module AuthHelper
  # Mocks the generation of a JWT token string.
  # IMPORTANT: This should NOT include the "Bearer " prefix.
  def generate_jwt(user)
    JsonWebToken.encode(user_id: user.id)
  end
  
  # The header helper methods are now redundant, as the specs build the string directly.
  # You can safely remove manager_auth_header and owner_auth_header.
end