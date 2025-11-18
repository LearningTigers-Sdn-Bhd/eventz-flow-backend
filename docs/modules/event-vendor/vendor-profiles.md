# Vendor Profiles

## Model Snapshot

`vendor_profiles` table (Vendor-Centric)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint | primary key |
| `vendor_id` | bigint | required, unique, FK to `users` (vendor role) |
| `image_path` | string | optional asset path |
| `description` | text | optional business description |
| `category` | string | optional business category (e.g., Technology, Food & Beverage) |
| `person_in_charge` | string | optional contact person name |
| `address` | text | optional business address |
| `notes` | text | optional additional notes |
| `created_at` / `updated_at` | timestamps | standard Rails timestamps |

### Key Design

**One Profile Per Vendor:** Each vendor user has exactly one profile, regardless of how many groups they join or events they participate in. This is enforced by a unique index on `vendor_id`.

**Creator Tracking:** The vendor's creator is tracked via `users.created_by_id`, not in the profile table.

**Group Membership:** Vendor-to-group relationships are managed separately through `group_affiliates` table.

---

## Vendor: View Profile

`GET /v1/vendor_profile`

Retrieves the authenticated vendor's profile.

**Auth:** Bearer token (must be a vendor user)

**Success (200):**

```json
{
  "id": 12,
  "vendor_id": 27,
  "image_path": "/cdn/vendor.png",
  "description": "Premium technology solutions provider.",
  "category": "Technology",
  "person_in_charge": "John Doe",
  "address": "123 Main St, City, Country",
  "notes": "Specializing in event management systems.",
  "created_at": "2025-11-10T07:20:00Z",
  "updated_at": "2025-11-10T08:15:12Z",
  "vendor": {
    "id": 27,
    "full_name": "Acme Corp",
    "email": "contact@acme.com",
    "phone": "+1234567890"
  }
}
```

**Errors:**
- `403 Forbidden` – current user is not a vendor

---

## Vendor: Update Profile

`PATCH /v1/vendor_profile`

Updates the authenticated vendor's profile.

**Auth:** Bearer token (must be a vendor user)
**Body:**

```json
{
  "vendor_profile": {
    "image_path": "/cdn/vendor.png",
    "description": "Updated description",
    "category": "Technology",
    "person_in_charge": "Jane Doe",
    "address": "456 New St, City, Country",
    "notes": "Updated notes"
  }
}
```

**Success (200):**

```json
{
  "id": 12,
  "vendor_id": 27,
  "image_path": "/cdn/vendor.png",
  "description": "Updated description",
  "category": "Technology",
  "person_in_charge": "Jane Doe",
  "address": "456 New St, City, Country",
  "notes": "Updated notes",
  "created_at": "2025-11-10T07:20:00Z",
  "updated_at": "2025-11-18T09:30:00Z",
  "vendor": {
    "id": 27,
    "full_name": "Acme Corp",
    "email": "contact@acme.com",
    "phone": "+1234567890"
  }
}
```

**Errors:**
- `403 Forbidden` – current user is not a vendor
- `422 Unprocessable Content` – validation errors

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
