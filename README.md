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

## 🔐 Payment Environment Variables (Razorpay Sandbox)

Add these to your backend environment (`.env`, `.envrc`, or deployment secrets):

```bash
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxx
```

Notes:
- `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` are used to create Razorpay orders and verify checkout signatures.
- `RAZORPAY_WEBHOOK_SECRET` is used to verify incoming webhook signatures.
- Never hardcode these in source code.

Webhook setup (Razorpay dashboard):
- URL: `https://<your-api-domain>/v1/public/payments/webhook`
- Events: `payment.captured`, `payment.failed`

---

## ✅ Registration Payment Test Plan (Sandbox)

Use this checklist before going live.

### 1) Backend automated tests

```bash
bundle exec rspec spec/requests/v1/public/payments_spec.rb
bundle exec rspec spec/requests/v1/public/registrations_spec.rb
```

Expected:
- payment order endpoint returns order payload for pending tickets
- verify endpoint transitions ticket to `status: purchased`, `payment_status: paid`
- webhook valid signature updates status correctly
- invalid signature requests are rejected

### 2) Manual happy path (paid ticket)

1. Start a new public registration with a paid ticket.
2. Complete details + confirm information.
3. On payment step, click `Proceed to Razorpay Sandbox`.
4. Complete sandbox checkout.
5. Confirm ticket state in DB/API:
   - before payment: `status = pending_payment`, `payment_status = pending`
   - after success: `status = purchased`, `payment_status = paid`

### 3) Manual failure path

1. Start payment but fail/cancel in Razorpay sandbox.
2. Confirm API/UI shows failure and allows retry.
3. Confirm ticket remains non-paid:
   - `status = pending_payment`
   - `payment_status = failed` (or `pending`, depending on fail timing)

### 4) Existing ticket checks

1. Re-enter with email that already has `pending_payment` ticket.
2. Verify flow routes to payment step directly.
3. Re-enter with email that has paid ticket.
4. Verify warning is shown and duplicate registration is discouraged.

### 5) Webhook validation

1. Trigger sandbox webhook for `payment.captured`.
2. Confirm backend accepts valid `X-Razorpay-Signature`.
3. Confirm invalid webhook signature is rejected (`422`).

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

## 🛰️ RfiDex device API (RFID)

The RfiDex desk and gate apps talk to this backend with an **event-scoped `rfid`
API key**. The wire format is `rfidex-core::contract`; answers are unwrapped
JSON, errors are `{error, message, holder, binding}` with `message` carrying the
human text. Nothing in a device reply contains an email or a phone number.

### Issuing and revoking a key

```bash
# org owner only; event must have API access enabled
curl -X POST "$HOST/v1/events/$EVENT_ID/api_keys" \
  -H "Authorization: Bearer $OWNER_JWT" -H 'Content-Type: application/json' \
  -d '{"name":"Desk A","scope":"rfid"}'
# → 201 { "raw_key": "rfd_<16 hex>_<64 hex>", ... }   save it once, it is not shown again
```

The key is recognised by its indexed `rfd_` prefix and verified with bcrypt.
Revoke it the same way as any other key (`DELETE
/v1/events/:event_id/api_keys/:id`); revocation takes effect on the next
request. An `rfid` key can reach **only** the seven device routes below, and
only for its own event — never the panel API and never the staff RFID routes.

### Device routes (key only)

| Route | Purpose |
|---|---|
| `POST /v1/rfid/stations/heartbeat` | Registers the station, returns the event settings |
| `GET /v1/rfid/cache` | Full offline snapshot (always full; `since` is ignored on purpose) |
| `GET /v1/rfid/tickets/search?by=name\|email\|phone&q=…` | Fallback search, paid tickets only, hints masked |
| `POST /v1/rfid/desk_scans` | Check a guest in; idempotent per `operation_id` |
| `POST /v1/rfid/bindings` | Link a sticker; first committed binding wins |
| `GET /v1/rfid/bindings/lookup?uid_raw_hex=…` | Who holds this sticker right now |
| `POST /v1/rfid/observations` | Up to 50 gate readings per batch |

Every route needs the `X-RfiDex-Station` header (1–128 printable ASCII
characters; production sends the station UUID, the shared contract tests send
`desk-contract`). Observations additionally require that station to have sent a
heartbeat, because each stored reading cites the station row.

### Staff routes (signed-in users only)

Under `/v1/events/:event_id/rfid`: `GET summary`, `GET stations`,
`PATCH stations/:id`, `GET bindings`, `GET visits`, `GET anomalies`,
`GET visits.csv`, `PATCH settings`, `POST visits/:id/manual_exit`. Reads need
`EventPolicy#analytics?`, settings and corrections need `#update?`. **API keys
are refused on every one of them**, whatever their scope.

Manual exits need a reason and a time not before the visit's entry; a repeated
manual exit is refused and never writes a second correction. A station's role or
UID rule can only move through `PATCH stations/:id` with `reason` and
`confirm: true` — a heartbeat can never change them. Use `observation_ids` to
name readings from this station for a historical role correction; the visit
projection uses the corrected role without rewriting raw observation fields.
An unspecified reading keeps its captured role.

### The print workflow

`ticket.scanned` webhooks now carry `scan_source` (the `ScanLog.source` of the
first check-in: `rfid_desk` for RfiDex, `staff_scan`, `kiosk`, …). **Keep the
SalesCatalyst badge-print workflow OFF by default for RfiDex events**: RfiDex
prints on the desk PC through event-printing, and a second workflow would print
two badges. When the workflow owner adds the condition `scan_source !=
rfid_desk`, it can stay on permanently as a backup for guests checked in on the
EventzFlow page.

### Event settings

`PATCH /v1/events/:event_id/rfid/settings` accepts `rfid_mode` (`bind` or
`write`) and `require_check_in` (boolean). It changes nothing else on the event.
Setting `write` only records the mode — RfiDex still refuses physical writes
until the P4 hardware acceptance passes.

### Evidence and limits

- Raw readings are immutable evidence. A late binding, a late check-in or a
  staff correction updates the *current* outcome/anomalies and the visit
  projection; the reply a station was first given is replayed unchanged.
- `RFID_ROUTES`/`RFID_KEY_RE` live in `app/models/api_key.rb`; the wire shapes
  in `app/services/rfid/wire.rb`; the rules in `app/services/rfid/`.
- Contact hints reveal at most two email characters and four phone digits by
  design. Outside loopback the device API must stay on TLS.

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
