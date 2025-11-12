# Event Vendor Module Overview

The event vendor module groups every feature available to partners who join an event as `event_vendor`.
It covers profile management and visitor stamp tracking for non-ticket events.

## Feature Map

| Area | Summary | Docs |
| --- | --- | --- |
| Vendor Profiles | Auto-generated per group + editable details | [`vendor-profiles.md`](vendor-profiles.md) |
| Visitor Stamps | Stamp tracking system for visitors visiting vendors | *(below)* |
| STI Polymorphism | Exhibitor and Merchant vendor types | [`sti-polymorphism.md`](sti-polymorphism.md) |

## Architecture Highlights

- **Group Affiliations:** `GroupAffiliate` (assigning a vendor to a group) automatically creates a `VendorProfile` (see callback in `app/models/group_affiliate.rb`).
- **Profiles:** `VendorProfile` stores marketing copy and media for the vendor within a group.
- **Event Vendors:** `EventVendor` uses Single Table Inheritance (STI) to support two vendor types:
  - **Exhibitor**: For ticket-based events (`event.use_ticket = true`), can be independent or owned by an `ExhibitorOwner`
  - **Merchant**: For non-ticket events (`event.use_ticket = false`), base implementation
- **ExhibitorOwner:** Separate model for managing exhibitor owners (organizations that own multiple exhibitors). Exhibitors can exist independently without an owner.
- **Visitor Stamps:** `VisitorVendorStamp` records track when visitors are scanned by vendors. Visitors are event-scoped (one record per event per visitor) and have a `public_id` for scanning.
- **Visitors:** For events with `use_ticket=false`, visitors are created via webhook when users register. Visitors have a `public_id` that vendors can scan to create stamps.
- **Stamp Analytics:** Metrics are computed from `VisitorVendorStamp` records to track vendor engagement.

## STI Polymorphism

The EventVendor model uses Single Table Inheritance to support different vendor types based on the event's `use_ticket` flag. This allows the system to handle different requirements for ticket-based events (Exhibitors) and non-ticket events (Merchants).

**Key Features:**
- Automatic type selection based on `event.use_ticket`
- Exhibitor can be independent (no owner) or owned by an `ExhibitorOwner`
- Merchant is a base implementation for future extensions
- Unified API interface for both types
- Helper methods and scopes for querying independent vs owned exhibitors

See [STI Polymorphism Documentation](sti-polymorphism.md) for detailed information.

Use the linked documents for endpoint details, request/response payloads, and sample workflows.

## Visitor Stamp System

For non-ticket events (`use_ticket=false`), the system uses a stamp tracking system:

- **Visitor Registration:** When users register via QR code, a webhook is triggered to create a `Visitor` record via the visitor store endpoint (`POST /v1/events/:event_id/visitors`).
- **Visitor Scanning:** Vendors can scan a visitor's `public_id` using the stamp endpoint (`POST /v1/visitors/:public_id/stamps`) to create a `VisitorVendorStamp` record.
- **Stamp Analytics:** Vendors can view stamp counts via analytics endpoints to track visitor engagement.
