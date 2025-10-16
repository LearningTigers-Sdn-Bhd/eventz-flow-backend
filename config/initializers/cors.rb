# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Configuration for local development
  allow do
    # ⚠️ Replace 3001 with the actual port your React dev server uses
    origins 'http://localhost:3001'

    resource '*',
      # Allow these common methods
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      # THIS IS CRITICAL: Explicitly allow the Authorization and Content-Type headers
      headers: %w(Authorization Content-Type Accept),
      # Allows sending cookies (if you use them for session/refresh tokens)
      credentials: true
  end

  # ... (Add production block below)
end
