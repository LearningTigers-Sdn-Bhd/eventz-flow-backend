module RequestSpecHelper
  # Parse JSON response to Ruby hash
  def json
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  # Alias for consistency with AuthHelpers
  def json_response
    json
  end
end
