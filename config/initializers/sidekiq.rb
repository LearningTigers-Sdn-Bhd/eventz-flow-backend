# Sidekiq Configuration for Redis/Memurai connection
# Development: redis://localhost:6380/0 (Memurai on Windows, Change if you are using a different port or docker windows)
# Production: Set via REDIS_URL environment variable
if Rails.env.development?
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6380/0')
else
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.logger.level = Logger::INFO if Rails.env.production?
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
