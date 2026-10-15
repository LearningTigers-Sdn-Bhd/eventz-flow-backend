# Feature Spec — Sponsors + Event Sponsorship Tiers (Org Owner / Organizer / Event Admin)

## 1) Goal
Add a Sponsors feature that supports:
- [ ] Event-level sponsorship tracking (monetary + in-kind, receipts, notes, uploads)
- [ ] Global sponsor directory for re-use across events (org-scoped)
- [ ] Event-level optional Sponsorship Packages/Tiers to group sponsors when needed
- [ ] Reporting on sponsor contributions across events
- [ ] Historical integrity: sponsor contact details may differ per event and must be preserved
- [ ] Internal-only (no public display anywhere)

Key flexibility requirement:
- [ ] Events may use tiers/packages OR may skip tiers entirely.
- [ ] Event sponsorships must support standalone sponsorship records with no tier.
- [ ] Every event sponsorship record must have a title describing what is being sponsored.

---

## 2) Roles & Permissions

### Roles that can access Sponsors (Global Directory)
- [ ] org_owner
- [ ] organizer

### Roles that can access Sponsors inside an Event
- [ ] org_owner
- [ ] organizer
- [ ] event_admin (event-scoped only)

### Access Rules
- [ ] Sponsors module in sidebar: only org_owner/organizer.
- [ ] Event Sponsors tab/section: org_owner/organizer/event_admin (must have access to that event).
- [ ] Enforce org scoping on all endpoints.
- [ ] Enforce event scoping for event_admin.
- [ ] event_admin can lookup/select existing sponsors for event sponsorship creation (read-only lookup), but cannot manage global sponsors unless explicitly allowed.

---

## 3) Core Concepts / Entities
We need separation between:

### A) Sponsor (Global Master Record)
- [ ] Company/organization identity and default contact info
- [ ] Reusable across events
- [ ] Sponsor show page displays all events sponsored with links and totals

### B) Event Sponsorship (Event Record)
- [ ] A record of a sponsor’s contribution for a specific event
- [ ] Has a required title describing what is being sponsored
- [ ] Can be standalone (no tier) OR assigned under a tier/package

### C) Event Sponsorship Tier/Package (Event-level grouping)
- [ ] Optional structure per event (Platinum/Gold etc.)
- [ ] Used when organizers want structured sponsorship offerings
- [ ] Sponsors attach under tiers via event sponsorship records

### D) Sponsorship Payments
- [ ] Multiple received transactions (installments)

### E) Sponsorship Attachments
- [ ] Image/PDF uploads linked to event sponsorship (and optionally linked to payments)

Why separation matters:
- [ ] Sponsor master contact can change over time
- [ ] Event sponsorship keeps a per-event snapshot of contact details used at the time

---

## 4) Data Model (Proposed)

### 4.1 sponsors (global directory)
Fields:
- [ ] id (pk)
- [ ] org_id (fk)
- [ ] name (string, required)
- [ ] website (string, optional)
- [ ] industry (string, optional)
- [ ] default_email (string, optional)
- [ ] default_whatsapp (string, optional)
- [ ] default_contact_name (string, optional)
- [ ] default_contact_position (string, optional)
- [ ] notes (text, optional)
- [ ] logo_media_id OR logo_path (optional)
- [ ] is_active (boolean default true)
- [ ] created_by (fk users, optional)
- [ ] timestamps, soft_deletes

Indexes:
- [ ] unique(org_id, name) recommended (case-insensitive if possible)
- [ ] (org_id, is_active)

---

### 4.2 event_sponsorship_tiers (optional per event)
Purpose:
- [ ] Define tiers/packages inside an event when needed (not required for every event).

Fields:
- [ ] id (pk)
- [ ] org_id (fk)
- [ ] event_id (fk)
- [ ] name (string, required)
- [ ] description (text, nullable)
- [ ] sponsorship_type_default (enum: monetary, in_kind, mixed) nullable
- [ ] currency_default (string, default "MYR")
- [ ] suggested_value (decimal(12,2), nullable)
- [ ] capacity (int, nullable)
- [ ] benefits (text/json, nullable)
- [ ] sort_order (int, nullable)
- [ ] timestamps, soft_deletes

Indexes:
- [ ] (org_id, event_id)
- [ ] unique(event_id, name) recommended

---

### 4.3 event_sponsorships (per-event sponsorship record)
This is the primary event record.
- [ ] Supports tiered sponsorships OR standalone sponsorships (tier_id nullable).

Fields:
- [ ] id (pk)
- [ ] org_id (fk)
- [ ] event_id (fk)
- [ ] sponsor_id (fk) — prefer NOT NULL (allow null only for legacy “one-off”)

Tier linking:
- [ ] event_sponsorship_tier_id (fk, nullable) — NULL means standalone sponsorship (no tier)
- [ ] tier_name_snapshot (string, nullable) — recommended to preserve display if tier renamed/deleted

Required business field:
- [ ] title (string, required) — what is being sponsored

Sponsorship details:
- [ ] sponsorship_type (enum: monetary, in_kind, mixed) default mixed
- [ ] currency (string, default "MYR")
- [ ] total_sponsor_amount (decimal(12,2), nullable)
- [ ] received_total (decimal(12,2), nullable) — derived from payments
- [ ] last_received_at (datetime, nullable) — derived from payments

Other:
- [ ] description (text, nullable)
- [ ] status (enum: pending, partially_received, received, cancelled) default pending

Contact snapshot fields (per event):
- [ ] contact_name (string, nullable)
- [ ] contact_email (string, nullable)
- [ ] contact_whatsapp (string, nullable)
- [ ] contact_position (string, nullable)

Audit/admin:
- [ ] internal_owner_user_id (fk users, optional)
- [ ] confirmed_at (datetime, nullable)
- [ ] cancelled_at (datetime, nullable)
- [ ] cancel_reason (text, nullable)

- [ ] timestamps, soft_deletes

Indexes:
- [ ] (org_id, event_id)
- [ ] (org_id, sponsor_id)
- [ ] (event_id, sponsor_id)
- [ ] unique(event_id, sponsor_id, title) recommended to reduce accidental duplicates

---

### 4.4 event_sponsorship_payments (installments)
Fields:
- [ ] id (pk)
- [ ] event_sponsorship_id (fk)
- [ ] amount (decimal(12,2))
- [ ] currency (string)
- [ ] received_at (datetime)
- [ ] method (enum: bank_transfer, cash, card, cheque, other) nullable
- [ ] reference_no (string nullable)
- [ ] notes (text nullable)
- [ ] timestamps
- [ ] soft_deletes (optional)

Derived:
- [ ] event_sponsorships.received_total = SUM(payments.amount)
- [ ] event_sponsorships.last_received_at = MAX(payments.received_at)

---

### 4.5 event_sponsorship_items (optional; recommended)
- [ ] Use if you want mixed sponsorship broken down (multiple in-kind items + monetary components).

Fields:
- [ ] id (pk)
- [ ] event_sponsorship_id (fk)
- [ ] item_type (enum: monetary, in_kind)
- [ ] title (string)
- [ ] quantity (int nullable)
- [ ] unit_value (decimal(12,2), nullable)
- [ ] total_value (decimal(12,2), nullable)
- [ ] notes (text nullable)
- [ ] timestamps

---

### 4.6 event_sponsorship_attachments (images / PDFs)
Fields:
- [ ] id (pk)
- [ ] event_sponsorship_id (fk)
- [ ] payment_id (fk event_sponsorship_payments, nullable) — optional receipt-to-payment linkage
- [ ] media_type (enum: image, pdf, other)
- [ ] attachment_type (enum: contract, receipt, logo_pack, other) default other
- [ ] file_name
- [ ] mime_type
- [ ] file_size
- [ ] storage_disk
- [ ] storage_path
- [ ] uploaded_by (fk users)
- [ ] created_at
- [ ] soft_deletes (optional)

Validation:
- [ ] allow images: jpg, png, webp
- [ ] allow pdf
- [ ] max size configurable (e.g., 10–25MB)
- [ ] private storage only

---

## 5) UI/UX Requirements

### 5.1 Sidebar (Global)
- [ ] Add sidebar item: Sponsors (org_owner/organizer only)

Routes:
- [ ] /org/{org}/sponsors (index)
- [ ] /org/{org}/sponsors/create
- [ ] /org/{org}/sponsors/{id} (show)
- [ ] /org/{org}/sponsors/{id}/edit

Global Index includes:
- [ ] Sponsor name
- [ ] Industry (optional)
- [ ] Total events sponsored (distinct events, computed)
- [ ] Total sponsor amount / received (computed; grouped by currency)
- [ ] Search + filter (active/inactive, industry)

Global Show includes:
- [ ] Master sponsor info
- [ ] Summary cards (events sponsored, sponsorship count, totals)
- [ ] Breakdown table by event sponsorship (event link, title, tier, sponsor amount, received, status)

---

### 5.2 Event Page
- [ ] Add Event tab/section: Sponsors (org_owner/organizer/event_admin)

Layout:
- [ ] Tiers/Packages section (optional to use per event)
- [ ] All Sponsorships list (includes tiered + standalone)

Sponsorship list columns:
- [ ] Sponsor name
- [ ] Title (required)
- [ ] Tier (or Standalone)
- [ ] Type
- [ ] Sponsor Amount Value
- [ ] Received total + last received date
- [ ] Status
- [ ] Actions: View/Edit, Add payment, Upload files

Add Sponsorship flow:
- [ ] Step 1: Select Sponsor (search directory)
- [ ] Step 2: (Optional) Create Sponsor inline (org_owner/organizer only; event_admin restricted unless allowed)
- [ ] Step 3: Enter Event Sponsorship details (title required)
- [ ] Step 4: Choose Tier OR Standalone
- [ ] Step 5: Save
- [ ] Step 6: Add Payments (installments) and Attachments

Event Sponsorship detail:
- [ ] Sponsor master link
- [ ] Title + tier/standalone label
- [ ] Contact snapshot fields
- [ ] Payments list + totals
- [ ] Attachments list (preview/download)
- [ ] Audit info (created_by, updated_by)

Tier management inside event:
- [ ] Create/Edit/Delete tier
- [ ] Display sponsors grouped under tier
- [ ] Allow events to have zero tiers (standalone-only)

---

## 6) Validations & Business Rules
- [ ] Sponsor name required and unique per org (recommended).
- [ ] Tier name unique per event (recommended).
- [ ] Event sponsorship title required.
- [ ] Event sponsorship must belong to same org as event + sponsor.
- [ ] sponsor_amount_value >= 0
- [ ] Payment amount > 0 (unless refunds supported later)
- [ ] Allow received_total > sponsor_amount_value with warning
- [ ] Derive received_total and last_received_at from payments
- [ ] Status auto-logic:
  - [ ] pending if received_total = 0
  - [ ] partially_received if 0 < received_total < sponsor_amount_value
  - [ ] received if received_total >= sponsor_amount_value
  - [ ] cancelled if cancelled_at set
- [ ] Prefill contact snapshot from sponsor defaults, but store snapshot on save
- [ ] Attachments private and accessible only to authorized roles

---

## 7) Reporting / Aggregations
- [ ] Sponsor show aggregates:
  - [ ] events_count = COUNT(DISTINCT event_id)
  - [ ] sponsorship_count = COUNT(event_sponsorships.id)
  - [ ] totals by type (monetary vs in-kind) and by currency
- [ ] Tier summary aggregates per event:
  - [ ] sponsors count
  - [ ] sum sponsor_amount_value
  - [ ] sum received_total

---

## 8) API Endpoints (Laravel-style)

### Sponsors (global) — org_owner/organizer only
- [ ] GET    /api/orgs/{org}/sponsors
- [ ] POST   /api/orgs/{org}/sponsors
- [ ] GET    /api/orgs/{org}/sponsors/{sponsor}
- [ ] PUT    /api/orgs/{org}/sponsors/{sponsor}
- [ ] DELETE /api/orgs/{org}/sponsors/{sponsor} (soft delete)

### Sponsor lookup for event_admin (read-only)
- [ ] GET /api/orgs/{org}/sponsors/lookup?search=... (returns limited fields)

### Event Sponsorship Tiers — org_owner/organizer/event_admin (event scoped)
- [ ] GET    /api/orgs/{org}/events/{event}/sponsorship-tiers
- [ ] POST   /api/orgs/{org}/events/{event}/sponsorship-tiers
- [ ] PUT    /api/orgs/{org}/events/{event}/sponsorship-tiers/{tier}
- [ ] DELETE /api/orgs/{org}/events/{event}/sponsorship-tiers/{tier}

### Event Sponsorships — org_owner/organizer/event_admin (event scoped)
- [ ] GET    /api/orgs/{org}/events/{event}/sponsorships
- [ ] POST   /api/orgs/{org}/events/{event}/sponsorships
- [ ] GET    /api/orgs/{org}/events/{event}/sponsorships/{sponsorship}
- [ ] PUT    /api/orgs/{org}/events/{event}/sponsorships/{sponsorship}
- [ ] DELETE /api/orgs/{org}/events/{event}/sponsorships/{sponsorship}

### Payments — org_owner/organizer/event_admin (event scoped via sponsorship)
- [ ] POST   /api/.../sponsorships/{sponsorship}/payments
- [ ] PUT    /api/.../payments/{payment}
- [ ] DELETE /api/.../payments/{payment}

### Attachments — org_owner/organizer/event_admin (event scoped via sponsorship)
- [ ] POST   /api/.../sponsorships/{sponsorship}/attachments
- [ ] DELETE /api/.../attachments/{attachment}

---

## 9) Implementation Checklist (LLM Task Plan)

### 9.1 Migrations
- [x] Create migration: create_sponsors_table
- [x] Create migration: create_event_sponsorship_tiers_table
- [x] Create migration: create_event_sponsorships_table (include title + nullable tier_id + tier_name_snapshot)
- [x] Create migration: create_event_sponsorship_payments_table
- [x] Create migration: create_event_sponsorship_attachments_table
- [x] (Optional) Create migration: create_event_sponsorship_items_table

### 9.2 Models & Relationships
- [x] Implement Sponsor model (belongsTo Org, hasMany EventSponsorships)
- [x] Implement Event model relations (hasMany tiers, hasMany sponsorships)
- [x] Implement EventSponsorshipTier model (belongsTo Event, hasMany sponsorships)
- [x] Implement EventSponsorship model (belongsTo Sponsor/Event/Tier nullable, hasMany payments/attachments)
- [x] Implement Payment model (belongsTo sponsorship)
- [x] Implement Attachment model (belongsTo sponsorship, optional belongsTo payment)
- [x] (Optional) Implement Item model (belongsTo sponsorship)

### 9.3 Policies / Gates
- [x] SponsorPolicy: org_owner/organizer only (org scoped)
- [x] SponsorLookupPolicy: allow event_admin read-only lookup (org+event scoped)
- [x] EventSponsorshipTierPolicy: org_owner/organizer/event_admin (event scoped)
- [x] EventSponsorshipPolicy: org_owner/organizer/event_admin (event scoped)
- [x] PaymentPolicy: inherit EventSponsorshipPolicy via sponsorship
- [x] AttachmentPolicy: inherit EventSponsorshipPolicy via sponsorship

### 9.4 Services / Domain Logic
- [x] Implement Payment aggregation (update sponsorship received_total + last_received_at + status) in DB transaction
- [x] Implement snapshot prefill: default sponsor contact -> event sponsorship snapshot fields
- [x] Implement tier snapshot: set tier_name_snapshot on create/update

### 9.5 Controllers / Endpoints
- [x] Build Sponsors CRUD controllers (org_owner/organizer)
- [x] Build Sponsors lookup endpoint (event_admin read-only)
- [x] Build Event Sponsorship Tiers CRUD controllers (event scoped)
- [x] Build Event Sponsorships CRUD controllers (event scoped)
- [x] Build Payments CRUD endpoints (event scoped via sponsorship)
- [x] Build Attachments upload/delete endpoints (private storage)

### 9.6 UI
> See detailed frontend plan: `new-eventzflow-panel/docs/features/sponsorship_feature_frontend.md`

- [ ] Add sidebar Sponsors item (org_owner/organizer only)
- [ ] Build global Sponsors index/create/edit/show pages
- [ ] Add Event Sponsors tab (org_owner/organizer/event_admin)
- [ ] Build tiers management UI inside event (optional usage)
- [ ] Build sponsorship list + detail pages inside event
- [ ] Build Add Sponsorship modal (title required + tier optional + sponsor search)
- [ ] Build payments UI (add installment, list payments)
- [ ] Build attachments UI (upload image/pdf, list, preview/download)

### 9.7 Tests
- [x] Test: org_owner/organizer can access global sponsors pages
- [ ] Test: event_admin cannot access global sponsors pages
- [ ] Test: event_admin can access event sponsors tab for permitted events
- [x] Test: event sponsorship requires title
- [x] Test: contact snapshot preserved when sponsor master contact changes
- [x] Test: payment aggregation updates received_total/last_received_at/status
- [ ] Test: attachments require auth and are not publicly accessible
- [x] Test: tier optional (standalone sponsorship works)

---

## 10) Edge Cases / Decisions
- [ ] Allow multiple sponsorships per sponsor per event (differentiated by title and/or tier)
- [ ] Use unique(event_id, sponsor_id, title) to prevent accidental duplicates
- [ ] Allow overpayment (received_total > sponsor_amount_value) with warning
- [ ] Decide currency rules (single org currency vs per sponsorship currency; aggregate by currency if multi)
- [ ] Tier deletion should not delete sponsorship records (soft-delete tier; sponsorship remains with snapshot)
- [ ] Event cloning should not copy payments/attachments by default

---

## 11) Acceptance Criteria (v1)
- [ ] org_owner/organizer can create/edit sponsors in global directory.
- [ ] org_owner/organizer/event_admin can manage event sponsorship tiers (optional per event).
- [ ] org_owner/organizer/event_admin can create event sponsorships as standalone or assigned to a tier.
- [ ] Event sponsorship title is required and stored.
- [ ] Event sponsorship stores per-event contact snapshot and preserves history.
- [ ] Payments support multiple installments; totals update correctly.
- [ ] Attachments support image/pdf and are private.
- [ ] Sponsor show page displays event sponsorship breakdown with links.
- [ ] No public sponsor display anywhere.
