# Repository Guidelines

## Project Structure & Module Organization
- Rails 8 API on Ruby 3.4.7. Core code is in `app/` (`controllers/` for HTTP endpoints, `models/` for Active Record, `services/` for orchestration, `policies/` for Pundit authorization, `jobs/` for async work, `views/` mostly for mailers).
- Shared helpers live in `app/lib` and `lib/`. API docs and workflows live in `docs/` and `swagger/`.
- Specs mirror the app layout under `spec/` (`requests/`, `models/`, `policies/`, `services/`, `features/`), with factories in `spec/factories`.
- Environment and secrets are in `config/` and `config/credentials`. Docker compose files sit at the repo root.

## Build, Test, and Development Commands
- `bundle install` — install gems.
- `bin/rails db:prepare` — create, migrate, and seed the local database.
- `bin/rails server` — run the API locally (defaults to port 3000).
- `bundle exec rspec` — run the test suite.
- `docker compose up --build` — start the app plus dependencies via the provided compose files.

## Coding Style & Naming Conventions
- Ruby/Rails defaults: 2-space indentation and UTF-8.
- Use snake_case for files/methods/variables, CamelCase for classes/modules. Controllers follow RESTful naming (`ThingsController`, actions `index/show/create/update/destroy`). Policies are `SomethingPolicy` with `Scope` classes for queries.
- Keep services single-purpose; name them `SomethingService` and place in `app/services`.
- Prefer PORO serializers or the existing `fast_jsonapi` setup for consistent JSON shapes.

## Testing Guidelines
- RSpec uses Shoulda Matchers, FactoryBot, DatabaseCleaner, and Pundit matchers (`spec/rails_helper.rb`). Place new specs alongside their code (`spec/requests` for endpoints, `spec/models` for validations/associations, `spec/policies` for authorization logic).
- Name files `*_spec.rb` and describe behaviors, not methods. Use factories for setup; avoid hitting external services.
- Run `bundle exec rspec` before pushing; apply `bin/rails db:test:prepare` if the schema changes.

## Commit & Pull Request Guidelines
- Follow conventional commits seen in history (`feat: ...`, `fix: ...`, `chore: ...`, `docs: ...`). Example: `feat: add vendor invitation feature`.
- For PRs: summarize the change and impact, link issues/tickets, list key endpoints or data shape changes, and attach test output (`bundle exec rspec`). Screenshots are optional and mostly unnecessary for this API.

## Security & Configuration Tips
- Keep secrets in credentials or environment variables; never commit `.env` contents or API keys.
- Validate authorization with Pundit in controllers and add matching policy specs. Sanitize user input at the model/service layer.
