# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'shoulda/matchers'

# --- Shoulda Matchers Configuration ---
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# --- Require support files (helpers, shared contexts, etc.) ---
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

# --- Maintain test schema ---
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# --- RSpec Core Configuration ---
RSpec.configure do |config|
  # Fixture path
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  # FactoryBot methods (build, create, etc.)
  config.include FactoryBot::Syntax::Methods

  # Include custom request helpers (json helper, etc.)
  config.include RequestSpecHelper, type: :request if defined?(RequestSpecHelper)

  # --- DatabaseCleaner setup ---
  config.use_transactional_fixtures = true

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # --- Ensure cookie jar works in API-only request specs ---
  # This patch restores cookie support for ActionDispatch in API mode.
  config.before(:each, type: :request) do
    allow_any_instance_of(ActionDispatch::Request)
      .to receive(:cookie_jar)
      .and_return(ActionDispatch::Cookies::CookieJar.build(request, {}))
  end

  # Automatically infer spec type (model, request, etc.) from file location
  config.infer_spec_type_from_file_location!

  # Filter Rails gems in backtraces
  config.filter_rails_from_backtrace!

  # Uncomment if you want to filter out specific gems
  # config.filter_gems_from_backtrace("gem name")
end
