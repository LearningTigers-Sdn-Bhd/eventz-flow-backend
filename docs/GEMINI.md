# Project-Wide Standards for AI-Driven Feature Development

Throughout this development, the AI agent must adhere to the following technical and structural standards when contributing to this Rails-based backend platform.

---

## 🧠 Core Development Guidelines

* **Mimic existing patterns**
  For model definitions, controller actions, policy structures, and RSpec test writing, follow the conventions observed in:

  * `app/models/`
  * `app/controllers/`
  * `app/policies/`
  * `spec/`

* **Follow Rails Best Practices**
  Always implement changes according to idiomatic Ruby on Rails conventions unless the existing codebase intentionally deviates. Prioritize convention over configuration where possible.

* **Propose Improvements Thoughtfully**
  If a better pattern, simplification, or architectural concern is discovered:

  * Document the suggestion within the task
  * Explain why it may be a better approach
  * Do not blindly follow existing patterns if they are flawed
  * Offer safer or more scalable alternatives as needed

* **Database Migrations**
  Use standard Rails migration syntax (`change`, `create_table`, `add_reference`, `t.timestamps`, etc). Support reversibility when applicable.

* **Strong Parameters**
  Ensure all controller actions use `permit` in `params.require()` blocks to whitelist attributes securely.

* **Error Handling**
  Use `app/lib/custom_error.rb` for consistent API error responses. Fall back to standard `rescue_from` or service object pattern where appropriate.

* **RSpec Standards**
  Align with existing style across model specs, request specs, policy specs, and service specs. Favor descriptive `describe` and `context` blocks, and always test authorization boundaries.

* **Naming Conventions**

  * Use `snake_case` for database columns, JSON keys, and method names
  * Use `CamelCase` for model, class, and policy names
  * Controller names should be plural and scoped (`V1::SomethingController`)

* **Associations**
  Define relationships explicitly, using `belongs_to`, `has_one`, and `has_many` with proper `dependent:` behavior and optionality.

* **Model Validations**
  Implement presence, format, uniqueness, inclusion, and length constraints where applicable. Always validate foreign keys unless explicitly optional.

* **Enums**
  Use Rails `enum` consistently for roles, statuses, booth types, and similar cases. Store as integers with defined mappings in the model.

* **Security**
  Ensure no privilege escalation. Enforce that:

  * Vendors can only manage their own data
  * Contractors can only modify assigned event kits
  * Admins and Organizers follow explicit policy scopes

---

## 📋 Task Format Compliance

* All `.md` specs must:

  * Follow the [Gemini Feature Spec Guidelines](./gemini_guidelines.md)
  * List all tasks as `[ ]` and subtasks consistently
  * End with a `## Codebase Guidelines` block summarizing the points above

---

By following these conventions and breaking down each complex feature into atomic, testable units, the AI agent ensures stability, readability, and maintainability across the codebase.

✅ For every task and sub-task completion, mark with an `x`.
