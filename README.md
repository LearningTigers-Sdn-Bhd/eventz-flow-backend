<div align="center">

# 🎉 Eventz Flow Backend

**Modern Event Management API** • Built with Rails 8.0 & Ruby 3.4.7

[![Ruby](https://img.shields.io/badge/Ruby-3.4.7-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0.3-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![RSpec](https://img.shields.io/badge/Tests-RSpec-green.svg)](https://rspec.info/)

*A comprehensive event management system featuring ticketing, exhibitor kits, vendor management, vouchers, lucky draws, and more.*

</div>

---

## 🚀 Quick Start

```bash
# 1. Install system dependencies (optional - app works without it)
# libvips enables optimized WebP image variants
brew install vips  # macOS/Homebrew Linux
# OR see docs/CROSS_PLATFORM_SETUP.md for other platforms

# 2. Install Ruby dependencies
bundle install

# 3. Setup environment (for image processing with Homebrew)
# The app auto-detects Homebrew, but explicit setup ensures it works
direnv allow  # If using direnv (recommended - auto-loads .envrc)
# OR manually: source .envrc

# 4. Setup database
rails db:create db:migrate db:seed

# 5. Start the server
rails server
# → http://localhost:3000
```

**Note**: The application works without libvips! Without it, images work normally but WebP variants won't be generated. The system automatically detects and adapts to vips availability.

📚 **For detailed setup across all platforms:** [docs/CROSS_PLATFORM_SETUP.md](docs/CROSS_PLATFORM_SETUP.md)

---

## 📦 Tech Stack

| Category | Technology |
|----------|-----------|
| **Framework** | Rails 8.0.3 (API mode) |
| **Language** | Ruby 3.4.7 |
| **Database** | PostgreSQL |
| **Background Jobs** | Sidekiq + Sidekiq-Cron |
| **Authentication** | JWT + BCrypt |
| **Authorization** | Pundit |
| **Serialization** | Fast JSON API |
| **Image Processing** | libvips + image_processing gem |
| **Testing** | RSpec + FactoryBot + Faker |
| **API Docs** | Rswag (OpenAPI/Swagger) |

---

## 🛠️ Development Commands

### Database
```bash
rails db:create              # Create database
rails db:migrate             # Run migrations
rails db:seed                # Seed database
rails db:reset               # Drop, create, migrate, seed
```

### Server
```bash
rails server                 # Start Rails server (port 3000)
bundle exec sidekiq          # Start background job processor
```

### Console
```bash
rails console                # Open Rails console
rails dbconsole              # Open database console
```

---

## 🧪 Testing

### Setting Up Parallel RSpec

**Prerequisites:**
- The `parallel_tests` gem is already included in the Gemfile
- PostgreSQL must be running
- **Database configuration** must include `TEST_ENV_NUMBER` suffix

**Configuration Required:**

Ensure your `config/database.yml` test section includes `<%= ENV['TEST_ENV_NUMBER'] %>`:

```yaml
test:
  <<: *default
  database: eventz_flow_api_test<%= ENV['TEST_ENV_NUMBER'] %>
```

This allows parallel_tests to create separate databases:
- `eventz_flow_api_test` (process 1)
- `eventz_flow_api_test2` (process 2)
- `eventz_flow_api_test3` (process 3)
- etc.

**Initial Setup (One-Time):**
```bash
# 1. Create parallel test databases (eventz_flow_api_test, eventz_flow_api_test2, etc.)
bundle exec rake parallel:create

# 2. Load schema into all parallel test databases
bundle exec rake parallel:prepare

# 3. (Optional) Drop parallel databases if needed
bundle exec rake parallel:drop
```

**How it works:**
- Creates multiple test databases (default: one per CPU core)
- Each process runs a subset of your test suite simultaneously
- Results in 2-4x faster test execution compared to sequential runs

### Run Tests (Fast - Parallel)
```bash
# Run all tests in parallel (uses all CPU cores)
bundle exec parallel_rspec spec/

# Run with specific number of processes
bundle exec parallel_rspec -n 4 spec/

# Run specific directories in parallel
bundle exec parallel_rspec spec/models/ spec/requests/

# View which tests run on which process
bundle exec parallel_rspec -n 4 spec/ --verbose
```

### Run Tests (Regular)
```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/models/user_spec.rb

# Specific line
bundle exec rspec spec/models/user_spec.rb:42

# With documentation format
bundle exec rspec --format documentation
```

### Test Database Maintenance
```bash
rails db:test:prepare        # Prepare single test database
rake parallel:prepare        # Prepare all parallel test databases
rake parallel:create         # Create parallel test databases
rake parallel:drop           # Drop parallel test databases
```

**Tip:** After migrations, run `bundle exec rake parallel:prepare` to sync schema across all test databases.

---

## 📚 API Documentation

### Swagger/OpenAPI
```bash
# Generate API documentation
rails rswag:specs:swaggerize

# View docs (after starting server)
# → http://localhost:3000/api-docs
```

---

## 🔧 Background Jobs

```bash
# Start Sidekiq
bundle exec sidekiq

# Monitor Sidekiq (in Rails console)
Sidekiq::Stats.new

# View scheduled jobs
Sidekiq::Cron::Job.all
```

---

## 📂 Project Structure

```
app/
├── controllers/v1/     # API endpoints (v1)
├── models/             # ActiveRecord models
├── policies/           # Pundit authorization policies
├── services/           # Business logic services
├── jobs/               # Background jobs
└── mailers/            # Email templates

spec/
├── models/             # Model tests
├── requests/v1/        # API integration tests
├── policies/           # Policy tests
└── services/           # Service tests

docs/                   # Additional documentation
```

---

## 🎯 Key Features

- ✅ **Event Management** - Create, manage, and track events
- ✅ **Ticketing System** - Excel import/export, QR codes
- ✅ **Exhibitor Kits** - Printing services, rentable items, custom requests
- ✅ **Vendor Management** - Stamps, rewards, profiles
- ✅ **Vouchers** - Creation, redemption, tracking
- ✅ **Lucky Draws** - Sessions, winners, gifts
- ✅ **Group Management** - Organizations, members, affiliates
- ✅ **Email Notifications** - Resend integration
- ✅ **Webhooks** - Event-driven notifications
- ✅ **API Keys** - Secure third-party integrations

---

## 📞 Support

For questions or issues, please check the documentation in the `docs/` folder or contact the development team.

---

<div align="center">

**Under Construction by LT Tech Team**

</div>
