# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Configuration for local development
  allow do
    # ⚠️ Replace 3001 with the actual port your React dev server uses
    origins 'http://localhost:3001',
            'http://localhost:3000',
            'http://localhost:5173',
            'http://127.0.0.1:3001',
            'http://127.0.0.1:3000',
            'http://127.0.0.1:5173'

    # resource '*',
    #   # Allow these common methods
    #   methods: [:get, :post, :put, :patch, :delete, :options, :head],
    #   # THIS IS CRITICAL: Explicitly allow the Authorization and Content-Type headers
    #   headers: %w(Authorization Content-Type Accept),
    #   # Allows sending cookies (if you use them for session/refresh tokens)
    #   credentials: true

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization', 'X-Refresh-Token'],
      max_age: 600

  end

  # Configuration for production
  allow do
    origins 'https://eventzflow.com',
            'https://www.eventzflow.com'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization', 'X-Refresh-Token'],
      max_age: 600
  end
end
