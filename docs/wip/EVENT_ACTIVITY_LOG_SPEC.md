# Event Activity Log — Spec & Implementation Plan

> **STATUS: DRAFT / WIP — scope may change or be dropped entirely.**
> **⚠️ DO NOT COMMIT ANYTHING FOR THIS FEATURE (code OR this doc) UNTIL THE HUMAN OWNER EXPLICITLY SAYS TO COMMIT.**
> The owner may abandon this mid-build and start fresh. Work in the working tree only.
> No `git add` / `git commit` / `git push` of any file touched for this feature, and do not commit this doc either.
> If you finish a chunk of work, stop and report — do not commit as a checkpoint.

## 1. Problem

Events run with ~3 accounts sharing access (org_owner + event staff). When something
changes (ticket archived, event deleted, voucher edited) nobody can currently see
**who** did it, scoped to **that event**. We already have a superadmin-only "System
Activity" 3-day audit trail (`UserActivity` model) but it has no per-event scoping and
no role-based visibility — it's account-wide and superadmin-only.

This spec adds a **second, event-scoped view** on top of the same underlying log,
visible to event staff (not just superadmin), with one exclusion rule: **org_owner's
own actions are hidden from the event-staff view** (org_owner still sees everything via
the existing superadmin System Activity page).

## 2. Non-goals (explicitly out of scope — do not build)

- **Seat ticketing** (`app/controllers/v1/seat_ticketing/*`) — separate subsystem,
  real effort, usage not confirmed. Skip entirely.
- **"Sensitive sponsorship/exhibitor-access activity"** — too vague as specified, not
  broken into concrete actions. Skip until named.
- **Tamper-proof / immutable audit trail** (DB triggers, append-only, compliance-grade
  guarantees). This was tried before and fully reverted (see `git log` around
  `db/migrate/20260918000001_create_audit_logs.rb` if it still exists in history —
  it was rolled back, not merged). Do not reintroduce that architecture. This feature
  is a **mutable, 3-day rolling activity feed** — same tier as the existing
  `UserActivity` model, not a compliance record.
- **Email delivery outcomes / reminder job results / webhook dispatch-receipt** — no
  human actor, doesn't belong in a "who did X" log. Out of scope for this spec.
- Field-level before/after diff (old value → new value) — **separate, already-scoped
  enhancement, not part of this spec.** Do not bundle it in. If asked to add it later,
  it hooks into `UserActivityRecorder` via an `after_action` capturing
  `resource.saved_changes` — ask the owner for that separate spec before building it.

## 3. Existing building blocks (reuse, do not reinvent)

| Piece | File | Reuse how |
|---|---|---|
| Activity model | `app/models/user_activity.rb` | Extend, don't replace |
| Activity writer | `app/services/user_activity_recorder.rb` | Extend `resolve_friendly_action` with new branches |
| Write call sites | `app/controllers/concerns/authenticable.rb:75` (`authenticate_user!`) | No change needed — this already fires on every authenticated request |
| Existing owner-only read endpoint | `app/controllers/v1/superadmin/system_activity_controller.rb` | Pattern-match for the new event-scoped controller; do not modify this file's behavior, only reference its shape |
| Existing event-scope resolver pattern | `app/controllers/concerns/authenticable.rb:168` `api_key_request_event_id` | Reuse this resolution logic (event_id from params/slug/public_id lookup) for step 4 below |
| Per-event role | `app/models/event_assignment.rb` (`event_admin`, `event_team_member`, `business_host`, `business_matching_admin`) | Use for Pundit policy scope, not `User.role` |
| Account-wide role | `User.role` enum (`org_owner`, `organizer`, `member`, `vendor`, `exhibitor`, `exhibition_contractor`) | Use only to detect/exclude `org_owner` actor rows |
| Existing category badge/UI pattern | `new-eventzflow-panel/src/components/pages/system-activity/system-activity-view.tsx` | Clone structure for the new event-level tab, do not modify the superadmin page |

## 4. Data model change

`user_activities` table has **no `event_id` column today**. Add one.

```ruby
# db/migrate/XXXXXXXXXXXXXX_add_event_id_to_user_activities.rb
class AddEventIdToUserActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :user_activities, :event_id, :bigint
    add_index :user_activities, [:event_id, :created_at]
    add_index :user_activities, [:event_id, :category]
    # No foreign key constraint needed — matches existing style (user_id also
    # has no FK constraint in this table per current schema.rb). Follow suit
    # unless you check and find newer tables in this repo do use FKs.
  end
end
```

Nullable — plenty of `UserActivity` rows are not event-scoped (auth, API keys, users
CRUD) and should stay `event_id: nil`.

### Resolving `event_id` at write time

In `UserActivityRecorder.record` (`app/services/user_activity_recorder.rb`), add
resolution of `event_id` from the request, following the same precedence as
`api_key_request_event_id` in `authenticable.rb`:

1. `request.params[:event_id]` if integer-shaped
2. `request.params[:id]` when `request.params[:controller] == 'v1/events'`
3. `request.params[:event_slug]` / `request.params[:slug]` → resolve via `Event.with_deleted.friendly.find_by(slug: ...)`
4. `request.params[:public_id]` → resolve via `Ticket.find_by(public_id: ...)&.event_id || Visitor.find_by(public_id: ...)&.event_id`
5. Otherwise `nil`

Do not duplicate this as a copy-paste of `api_key_request_event_id` — either extract a
shared method both call, or accept some duplication if extraction touches too many
files. Prefer extraction into a small module (e.g. `app/services/event_id_resolver.rb`)
called from both places, kept under ~30 lines.

Add `event_id: resolved_event_id` to the `UserActivity.create!` call.

## 5. `resolve_friendly_action` — new branches needed

File: `app/services/user_activity_recorder.rb`, method `resolve_friendly_action`.

Current categories: `ticketing`, `business_matching`, `vouchers`, `lucky_draw`,
`seating`, `events`, `exhibitor`, `auth`, `general` (fallback).

Extend/add branches per this table. Keep the existing `if/elsif` chain style — do not
refactor to a different dispatch pattern. Match on `controller`/`path`/`action` the
same way existing branches do; use real controller names below (verified against this
codebase, not guessed):

| New/expanded category | Controllers to match | Friendly action names needed |
|---|---|---|
| `ticketing` (expand existing) | `tickets_controller.rb`, `ticket_applications_controller.rb`, `ticket_exports_controller.rb` | Add: "Archived Ticket", "Restored Ticket", "Reprinted Ticket", "Reviewed Application" (approve/reject), "Updated RSVP Status", "Changed Ticket Type", "Changed Payment Status", "Exported Tickets", "Imported Tickets" |
| `visitors` (new) | `visitors_controller.rb` | "Created Visitor", "Updated Visitor", "Deleted Visitor", "Checked In Visitor", "Un-scanned Visitor Check-in", "Imported Visitors" |
| `events` (expand existing) | `events_controller.rb` | Distinguish beyond create/update/delete: "Published Event", "Completed Event", "Cancelled Event", "Archived Event", "Restored Event" — likely distinguished by a `status`/`state` param or dedicated action name; **read `events_controller.rb` update/publish-related actions first** to find the real trigger (may be a status field change, not a separate route) |
| `event_setup` (new) | `event_staff_controller.rb` (staff assignments), `ticket_types_controller.rb` + `ticket_type_price_tiers_controller.rb` (ticket types & price tiers) | "Assigned Event Staff", "Removed Event Staff", "Updated Staff Role", "Created Ticket Type", "Updated Ticket Type", "Deleted Ticket Type", "Updated Price Tier" |
| `seating` (expand existing) | `seating_groups_controller.rb`, whatever controller owns seating plans/table assignments (locate via `grep -rl "seating_plan\|table_assignment" app/controllers`) | "Created Seating Plan", "Assigned Table", "Created Seating Group", "Added Group Member", "Removed Group Member" |
| `exhibitor` (expand existing) | `exhibitor_booths_controller.rb`, `exhibitor_booth_prices_controller.rb`, `exhibitor_booth_price_tiers_controller.rb`, `exhibitor_kits_controller.rb`, `exhibitor_kit_payments_controller.rb`, `exhibitor_packages_controller.rb`, `exhibitor_team_member_limits_controller.rb`, `exhibitor_team_member_payments_controller.rb`, `exhibitor_vouchers_controller.rb`, `exhibitor_zones_controller.rb`, `event_vendors_controller.rb`, `event_vendor_profiles_controller.rb`, `event_exhibition_contractors_controller.rb` | Distinguish per-controller instead of one generic "Managing Exhibitor Data": "Created/Updated Booth", "Updated Booth Pricing", "Created/Updated Kit", "Recorded Kit Payment", "Updated Package", "Updated Team Member Limit", "Recorded Team Member Payment", "Issued Exhibitor Voucher", "Updated Zone", "Registered Vendor", "Added Exhibition Contractor" |
| `payments` (new) | `received_payments_controller.rb`, `event_payment_gateways_controller.rb`, `event_sponsorship_payments_controller.rb` | "Order Requested", "Payment Verified", "Payment Failed", "Recorded Sponsorship Payment" |
| `sponsorships` (new) | `event_sponsorship_tiers_controller.rb`, `event_sponsorships_controller.rb`, `event_sponsorship_items_controller.rb`, `event_sponsorship_attachments_controller.rb` | "Created Sponsorship Tier", "Created Sponsorship", "Updated Sponsorship Item", "Uploaded Sponsorship Attachment" |
| `business_matching` (expand existing) | already matched broadly — add: availability, tags/defaults, host assignment (`business_host` role in `event_assignment.rb`), leads (`event_leads_controller.rb`) | "Updated Availability", "Updated Matching Tags", "Assigned Business Host", "Scanned Lead" (already partially covered — verify no duplicate with existing `Exhibitor Scanned Attendee Lead` branch) |
| `lucky_draw` (expand existing) | `app/controllers/v1/lucky_draw/*` | Distinguish: "Created Lucky Draw Session", "Added Gift/Prize", "Drew Winner", "Assigned Prize" |
| `wish_wall` (new) | `app/controllers/v1/wishes_controller.rb` | "Created Wish", "Approved Wish", "Rejected Wish", "Deleted Wish" |
| `certificates` (new) | `certificate_templates_controller.rb`, `certificates_controller.rb` | "Created Certificate Template", "Requested Certificate Batch", "Issued Certificate" |
| `groups` (new — owner-only tier) | `groups_controller.rb`, `group_members_controller.rb`, `group_affiliates_controller.rb` | "Created Group", "Updated Group", "Added Group Member", "Removed Group Member" |

**Do not** try to make every branch perfectly exhaustive on the first pass — match the
existing code's pragmatic style (fallback to a generic `"#{action.humanize}"` label
inside each category when a specific sub-case isn't worth a dedicated `case` branch,
same as the existing `else` arms already do).

## 6. Owner-only tier additions (still superadmin-scoped, not event-scoped)

These extend the *existing* `system_activity_controller.rb` flow (superadmin-only),
not the new event-scoped one. Add branches for:

- Users/team/vendors/contractors CRUD — likely already partially caught by the
  `general` fallback; check `app/controllers/v1/users_controller.rb` (if it exists)
  and give it a proper `users` category instead of falling through to `general`.
- `api_keys_controller.rb`, `event_api_keys_controller.rb` — "Created API Key",
  "Revoked API Key".
- `payment_details_controller.rb` — "Viewed Payment Details", "Updated Payment
  Details".
- Auth/security granularity — `authentication_controller.rb` already logs
  login/logout; add failed-login and session-revoke events if those exist as distinct
  controller actions (check `user_sessions_controller.rb` or similar for revoke).

## 7. New event-scoped read endpoint

New controller: `app/controllers/v1/events/activity_logs_controller.rb` (namespace
under the event, following this codebase's nesting convention — check an existing
nested-under-event controller like `event_locations_controller.rb` for the route/param
pattern to copy).

```ruby
# GET /v1/events/:event_id/activity_logs
class V1::Events::ActivityLogsController < ApplicationController
  before_action :set_event

  def index
    authorize @event, :view_activity_log?   # new Pundit policy method, see below

    scope = UserActivity.where(event_id: @event.id).within_days(3).includes(:user).recent
    scope = scope.for_category(params[:category]) if params[:category].present?

    # Exclusion rule: hide org_owner-authored rows from event-staff view.
    scope = scope.joins(:user).where.not(users: { role: User.roles[:org_owner] })

    # ... paginate + serialize, same shape as system_activity_controller.rb's
    # activities_data block — copy that mapping, don't reinvent the JSON shape.
  end

  private

  def set_event
    @event = Event.friendly.find(params[:event_id])
  end
end
```

**Org_owner viewing their own event**: org_owner already has full access via the
existing superadmin System Activity page — do not also give org_owner a filtered view
here. Gate this endpoint to non-org_owner event staff only (`current_user.org_owner?`
→ 403, or simply don't surface the nav tab to org_owner in the frontend — confirm
which with the owner before building; default to backend-enforcing it since frontend
gating alone isn't real access control).

### Pundit policy

Add `view_activity_log?` to `app/policies/event_policy.rb` (check that file exists and
follow its existing pattern for other event-scoped permission checks). Rule: user must
have an `EventAssignment` for this event (any role) AND must not be `org_owner`.

## 8. Frontend

New tab/page under the event detail area (find the existing event detail route
structure under `new-eventzflow-panel/src/app/` — likely
`src/app/(auth)/events/[slug]/...` or similar, verify actual path before assuming).

Clone the structure of
`new-eventzflow-panel/src/components/pages/system-activity/system-activity-view.tsx`
for the table/filter/modal UI, but:

- Scope the query to the current event (`event_id` from route params), hit the new
  `/v1/events/:event_id/activity_logs` endpoint instead of
  `/v1/superadmin/system_activity`.
- Drop the "Currently Active Users" tab and "Include superadmin actions" checkbox —
  neither applies here (org_owner rows are always excluded server-side, not optional).
- Drop the deployment-safety banner (`renderDeploymentBanner`) — that's a superadmin
  concept, not relevant per-event.
- Keep: category filter, pagination, the details modal.
- New API module: `src/lib/api/event-activity-log/` following the existing
  `request.ts` / `response.ts` / `endpoints.ts` / `index.ts` pattern used by every
  other module in `src/lib/api/`.

## 9. Build order

1. Migration: add `event_id` to `user_activities` (§4)
2. `event_id` resolver, wired into `UserActivityRecorder.record` (§4)
3. Expand `resolve_friendly_action` branches, category by category from §5 — commit
   nothing, but it's fine to build incrementally and verify each category with a
   manual request/rails console check before moving to the next
4. Owner-only tier additions to existing superadmin controller (§6)
5. New event-scoped controller + Pundit policy (§7)
6. Frontend tab (§8)

## 10. Verification checklist (before reporting done)

- [ ] `rails console`: trigger one action per new category, confirm a `UserActivity`
      row is created with correct `category`, `action_name`, and `event_id`
- [ ] Confirm `event_id` is `nil` for non-event actions (login, API key creation) —
      should not error, should not misattribute to an event
- [ ] Confirm org_owner's own actions do NOT appear in `/v1/events/:id/activity_logs`
      response, but DO still appear in `/v1/superadmin/system_activity`
- [ ] Confirm a non-org_owner event staff member with an `EventAssignment` on this
      event CAN see the endpoint; a user with no assignment on this event CANNOT
      (403 via Pundit)
- [ ] Frontend tab renders, filters by category, paginates, opens detail modal
- [ ] `bun run check` (frontend) and existing Rubocop/rspec conventions pass for
      touched files
- [ ] **No commits made.** Confirm `git status` shows only uncommitted working-tree
      changes before reporting completion.

## 11. Open questions for the human owner (do not guess — ask)

- Confirm exact route/nesting under which event detail pages live (frontend) before
  building the new tab.
- Confirm whether `events_controller.rb` publish/complete/archive/restore are actually
  distinct actions/params today, or need new ones added to the controller itself
  (that would expand scope beyond just the activity log).
- Retention: reuse 3-day window (`within_days(3)`, same as owner tier) or does
  event-level need longer? Not specified — assume 3 days unless told otherwise.
