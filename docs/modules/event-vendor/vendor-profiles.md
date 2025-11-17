# Vendor Profiles

## Model Snapshot

`vendor_profiles` table

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint | primary key |
| `group_id` | bigint | required, FK to `groups` |
| `vendor_id` | bigint | required, FK to `users` (vendor role) |
| `image_path` | string | optional asset path |
| `vendor_name` | string | defaults to `"Vendor Name"` |
| `vendor_description` | text | optional marketing copy |
| `manager_id` | bigint | optional, FK to `users` (organizer who assigned vendor) |
| `created_at` / `updated_at` | timestamps | standard Rails timestamps |

### Automatic creation

A `GroupAffiliate` created (assigning a vendor to a group) triggers:

```ruby
VendorProfile.find_or_create_by(group: group, vendor: vendor)
```

This guarantees every vendor has a profile per group without a manual API call.

---

## Dashboard: Update Profile

`PATCH /v1/events/:event_id/vendors/:id/profile`

Updates the authenticated vendor's profile for a specific event. The profile content still comes from the underlying group/vendor relationship, but the route now scopes access through the `EventVendor` record.

**Auth:** Bearer token (must be the vendor attached to the `EventVendor`)
**Body:**

```json
{
  "vendor_profile": {
    "image_path": "/cdn/vendor.png",
    "vendor_name": "Acme Corp",
    "vendor_description": "Premium partner booth."
  }
}
```

**Success (200):**

```json
{
  "id": 12,
  "group_id": 4,
  "vendor_id": 27,
  "image_path": "/cdn/vendor.png",
  "vendor_name": "Acme Corp",
  "vendor_description": "Premium partner booth.",
  "created_at": "2025-11-10T07:20:00Z",
  "updated_at": "2025-11-10T08:15:12Z"
}
```

**Errors:**
- `404 Not Found` – group missing
- `403 Forbidden` – current user is not the assigned vendor for this group
- `422 Unprocessable Content` – validation errors (e.g., duplicate profile)

---

## EventVendor Model Snapshot

`event_vendors` table

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint | primary key |
| `event_id` | bigint | required, FK to `events` |
| `vendor_id` | bigint | required, FK to `users` (vendor role) |
| `redirect_url` | string | required target URL for public redirect |
| `poster_url` | string | optional marketing asset |
| `created_at` / `updated_at` | timestamps | standard Rails timestamps |

- **Uniqueness:** `(event_id, vendor_id)` is unique, enforcing one vendor slot per event.
- **Associations:** `has_many :visitor_vendor_stamps`; belongs to both `event` and `vendor`.
- **Purpose:** Holds all event-specific vendor data (redirect URL, poster). **It does not create a new VendorProfile**—the existing group-level profile is reused.

---

## Related Data

- **VisitorVendorStamp:** stores `visitor_id`, `event_vendor_id`, timestamps. Used for tracking visitor visits to vendors in non-ticket events.
- **Stamp Analytics:** Stamp counts are computed from `VisitorVendorStamp` records to track vendor engagement.
