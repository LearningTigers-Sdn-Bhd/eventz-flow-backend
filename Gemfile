source "https://rubygems.org"

ruby "3.4.7"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.0.3'

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# --- Authentication & Authorization ---
# bcrypt is included by default via has_secure_password
gem "pundit"


# --- API Serialization (Performance) ---
# fast_jsonapi is a high-performance serializer (fork of Netflix's)
gem "fast_jsonapi"

# --- Background Processing (Webhooks, Notifications) ---
gem "sidekiq"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Ruby 3.5+ compatibility - these will no longer be default gems
gem "fiddle"
gem "ostruct"

gem "jwt"

gem "friendly_id", "~> 5.5"

# Email delivery with Resend
gem "resend"

# Groupdate for date-based grouping in ActiveRecord
gem "groupdate"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# --- Excel/CSV Processing ---
gem "caxlsx"
gem "roo"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  # Testing Framework
  gem "rspec-rails", "~> 6.0"
  # Parallel test execution for faster test runs
  gem "parallel_tests"
  # Test Data Generation
  gem "factory_bot_rails"
  gem "faker"
  gem "rswag"
  gem "pry"
end

group :test do
  # Shorthand matchers for testing models
  gem "shoulda-matchers"
  # For Pundit policy testing
  gem "pundit-matchers"
  # Ensures a clean database slate between tests
  gem "database_cleaner"
  # For stubbing HTTP requests in tests
  gem "webmock"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  gem 'letter_opener_web'
end
gem "sidekiq-cron", "~> 2.3"

gem "pagy", "~> 43.2"
