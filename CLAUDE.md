# EventzFlow Backend

Rails 8.0.3 **API-only** app. Ruby 3.4.7 (pinned in `.ruby-version` / `mise.toml`). PostgreSQL, Redis, Sidekiq (+ sidekiq-cron). Serves the Next.js panel in `../new-eventzflow-panel` (port 3001).

## Commands (verified against README/Gemfile)

```bash
bundle install                       # deps (brew install vips first for image variants)
rails db:create db:migrate db:seed   # database setup
rails server                         # API → http://localhost:3000
bundle exec sidekiq                  # background jobs (required for webhooks/emails)
rails console

# Tests — parallel is the default way to run the full suite
bundle exec rake parallel:prepare    # one-time / after every migration
bundle exec parallel_rspec spec/     # full suite, all cores
bundle exec rspec spec/path_spec.rb:42   # single file/line

# API docs (rswag / OpenAPI)
rails rswag:specs:swaggerize         # regenerate → served at /api-docs
```

Env vars come from `.env` via dotenv-rails (development/test only) and `.envrc` (direnv, Homebrew libvips paths). Never commit secrets; production config comes from real environment variables.

## Architecture

```
app/
├── controllers/v1/   # versioned API endpoints (~86 controllers)
├── models/           # ActiveRecord
├── policies/         # Pundit — one policy per resource
├── services/         # business logic lives HERE, not in controllers/models
├── serializers/      # jsonapi-serializer classes
├── jobs/             # Sidekiq jobs
├── channels/         # ActionCable (frontend uses @rails/actioncable)
└── mailers/          # email via Resend gem

spec/                 # mirrors app/: models, requests/v1, policies, services, jobs
                      # FactoryBot factories in spec/factories, Faker for data
```

Key gems and their roles: `pundit` (authorization), `jwt` + `bcrypt` (auth), `jsonapi-serializer` (responses), `pagy` v43 (pagination — see `pagy-43-docs.md` in repo root), `rack-attack` (rate limiting), `rack-cors` (CORS), `friendly_id` (slugs), `caxlsx`/`roo` (Excel), `prawn` + `rqrcode` (PDF/QR), `image_processing` + libvips (Active Storage variants).

## Auth model (must stay consistent with frontend)

- Access token: short-lived JWT (~15 min), sent by clients as `Authorization: Bearer <token>`.
- Refresh token: **HttpOnly Secure cookie** with jti rotation — never return it in a JSON body, never weaken the cookie flags.
- Refresh endpoint (`/v1/auth/refresh_token`) returns a new access token AND the `user` object (the frontend's silent init depends on both).
- Passwords: `has_secure_password` (bcrypt). Never log tokens or credentials.

## Rules for every new/changed endpoint

1. Controller goes in `app/controllers/v1/`, kept thin — delegate to a service object for anything beyond trivial CRUD.
2. **Pundit on every action**: `authorize record` for member actions, `policy_scope` for collections. No endpoint ships without a policy + policy spec (`pundit-matchers`).
3. Strong parameters always; never `params.permit!`.
4. Respond through a serializer class — never `render json: model` raw (leaks columns).
5. Paginate collections with pagy (see `docs/PAGINATION.md`).
6. Write a request spec in `spec/requests/v1/` (+ rswag doc for the endpoint) and model/service specs for new logic.
7. After adding migrations: `rails db:migrate` then `bundle exec rake parallel:prepare` or parallel tests will run against a stale schema.

## Security (data-storing system — non-negotiable)

- Authorization is Pundit-only; do not hand-roll role checks in controllers (roles: org_owner, organizer, member, vendor, exhibitor, exhibition_contractor — see `docs/EVENT_ROLES.md`).
- All external webhooks (e.g. Razorpay) must verify signatures and reject invalid ones with 422 — pattern exists in the payment flow, follow it.
- Keep `rack-attack` throttles in mind when adding auth-adjacent endpoints; don't exempt endpoints from it without reason.
- User-supplied files (Excel import, uploads) are untrusted: validate content type and size before processing.
- Use ActiveRecord parameter binding; no string-interpolated SQL.

## Docs

`docs/` holds feature guides: `EVENT_ROLES.md`, `PAGINATION.md`, `IMAGE_PROCESSING.md`, `TICKET_EXCEL_IMPORT_EXPORT.md`, `CROSS_PLATFORM_SETUP.md`, plus `docs/modules/`, `docs/plan/`, `docs/wip/`. `README.md` has the full command reference and Razorpay test plan.
