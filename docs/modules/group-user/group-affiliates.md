# Group Affiliates (Vendor Assignment)

## Model Snapshot

`group_affiliates` table

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint | primary key |
| `group_id` | bigint | required, FK to `groups`, unique |
| `vendor_id` | bigint | required, FK to `users` (vendor role) |
| `created_at` / `updated_at` | timestamps | standard Rails timestamps |

**Constraints:**
- Unique index on `group_id` (one vendor per group)
- Index on `vendor_id` (vendors can belong to multiple groups)
- Vendor must have `vendor` role

---

## Assign Vendor to Group

`POST /v1/groups/:group_id/affiliates`

Assigns a vendor to a group. Only org_owner can assign vendors.

**Auth:** Bearer token (org_owner required)

**Body:**

```json
{
  "group_affiliate": {
    "vendor_id": 7
  }
}
```

**Parameters:**
- `vendor_id` (required): User ID with `vendor` role

**Validation Rules:**
- Vendor must have `vendor` role
- Group can only have one vendor (if group already has a vendor, this will fail)
- Vendor can be assigned to multiple groups

**Success (201):**

```json
{
  "id": 1,
  "group_id": 1,
  "vendor_id": 7,
  "vendor": {
    "id": 7,
    "email": "vendor@example.com",
    "full_name": "Vendor Corp"
  },
  "created_at": "2025-11-11T03:25:00Z",
  "updated_at": "2025-11-11T03:25:00Z"
}
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner
- `404 Not Found` – group or vendor doesn't exist
- `422 Unprocessable Content` – validation errors (e.g., vendor doesn't have vendor role, group already has a vendor)

---

## Remove Vendor from Group

`DELETE /v1/groups/:group_id/affiliates`

Removes the vendor assignment from a group. Only org_owner can remove vendors.

**Auth:** Bearer token (org_owner required)

**Success (204):** No content

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner
- `404 Not Found` – group doesn't exist or has no vendor affiliate

---

## Use Case: Multi-Location Vendor Management

A vendor can be assigned to multiple groups to manage different locations or organizational units:

**Example:**
- Vendor "Mall Vendor Corp" is assigned to:
  - Group "Mall A" (group_id: 1)
  - Group "Mall B" (group_id: 2)

This allows the vendor to:
- View both groups in their dashboard
- Manage operations across multiple locations
- Maintain separate organizational structures per location

**API Flow:**
1. org_owner creates groups: `POST /v1/groups` (creates "Mall A" and "Mall B")
2. org_owner assigns vendor to Mall A: `POST /v1/groups/1/affiliates` with `vendor_id: 7`
3. org_owner assigns same vendor to Mall B: `POST /v1/groups/2/affiliates` with `vendor_id: 7`
4. Vendor can now view both groups: `GET /v1/groups` (returns groups 1 and 2)

---

## Relationship with Group Members

**Group Affiliates** and **Group Members** are separate concepts:

- **Group Members:** Users with roles `manager` or `member` who can manage or participate in group operations
- **Group Affiliates:** Users with `vendor` role who are assigned to groups for organizational purposes

Vendors cannot be added as group members. They are only associated with groups through `group_affiliates`.

---

## Automatic Vendor Profile Creation

When a vendor is assigned to a group via `GroupAffiliate`, a single `VendorProfile` is automatically created for that **group/vendor** pair (e.g., “KFC @ Imago Mall”). This profile stays at the group level.

Later, when that same vendor is added to an event, the system creates an `EventVendor` record (e.g., “KFC at Christmas Event”). The event record reuses the existing VendorProfile—no second profile is created. Event-specific details (redirect URL, posters, etc.) live on `EventVendor`.

Event-level profile settings are updated through `PATCH /v1/events/:event_id/vendors/:id/profile` (see [`vendor-profiles.md`](../event-vendor/vendor-profiles.md) for details). The `:id` here is the `EventVendor.id` that links the vendor to a specific event.

---

## Related Data

- **Group:** The group that the vendor is assigned to
- **User:** User with `vendor` role
- **GroupMember:** Separate from affiliates, used for manager/member assignments
- **VendorProfile:** Automatically created when vendor is assigned to group
