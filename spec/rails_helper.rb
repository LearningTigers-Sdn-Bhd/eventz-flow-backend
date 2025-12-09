# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'shoulda/matchers'
require 'pundit/matchers'

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
  # --- Configuration ---
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include Rails.application.routes.url_helpers

  # FactoryBot methods (build, create, etc.)
  config.include FactoryBot::Syntax::Methods

  # Include custom request helpers (json helper, etc.)
  config.include RequestSpecHelper, type: :request if defined?(RequestSpecHelper)

  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
  config.include Pundit::Matchers, type: :policy


  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.allow_remote_database_url = true
    DatabaseCleaner.clean_with(:truncation)
  end

  # --- Ensure cookie jar works in API-only request specs ---
  # This patch restores cookie support for ActionDispatch in API mode.
  config.before(:each, type: :request) do
    allow_any_instance_of(ActionDispatch::Request)
      .to receive(:cookie_jar)
      .and_return(ActionDispatch::Cookies::CookieJar.build(request, {}))
  end
end

# --- Shoulda Matchers Configuration ---
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
