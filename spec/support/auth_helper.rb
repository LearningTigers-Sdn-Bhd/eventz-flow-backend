# frozen_string_literal: true

module AuthHelpers
  def jwt_token(user)
    JwtService.generate_tokens(user)[:access_token]
  end

  def auth_headers(user)
    { 'Authorization' => "Bearer #{jwt_token(user)}" }
  end

  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
