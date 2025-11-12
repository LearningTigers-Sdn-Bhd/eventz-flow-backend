# Voucher Management API

## Overview

Event vendors manage their own vouchers per event. Each voucher belongs to:
- an `event`
- the authenticated `vendor` (`event_vendor` assignment)

Claims are tracked against attendee tickets through the `UserVoucher` join model.

## Authentication

All endpoints require a Bearer token:

```
Authorization: Bearer <access_token>
```

## Authorization

Only users assigned as `event_vendor` for the target event can access these routes. Controllers scope every query by `vendor_id = current_user.id`.

## Base URL

```
/v1/events/:event_id/vouchers
```

---

## Endpoints

### 1. List Active Vouchers

`GET /v1/events/:event_id/vouchers`

Returns non-deleted vouchers for the authenticated vendor.

**Response 200**

```json
[
  {
    "id": 1,
    "name": "DISCOUNT10",
    "active_status": true,
    "public_id": "550e8400-e29b-41d4-a716-446655440000",
    "rules": {
      "discount_percent": 10
    },
    "valid_until": "2025-12-31T23:59:59Z",
    "event_id": 42,
    "vendor_id": 7,
    "created_at": "2025-11-10T13:00:00Z",
    "updated_at": "2025-11-10T13:00:00Z",
    "deleted_at": null
  }
]
```

**Errors:** `404 Not Found` (event), `403 Forbidden` (not assigned).

---

### 2. List Soft-Deleted Vouchers

`GET /v1/events/:event_id/vouchers/soft_deleted`

Returns soft-deleted vouchers (`deleted_at` present).

---

### 3. Create Voucher

`POST /v1/events/:event_id/vouchers`

**Body**

```json
{
  "voucher": {
    "name": "discount10",
    "active_status": true,
    "rules": {
      "discount_percent": 10,
      "minimum_purchase": 50
    },
    "valid_until": "2025-12-31T23:59:59Z"
  }
}
```

**Notes**
- `vendor_id` auto-populates from `current_user`.
- `name` uppercased before save.
- `public_id` generated (UUID) for QR usage.

**Response 201** – voucher payload (same shape as list).

---

### 4. Update Voucher

`PATCH /v1/events/:event_id/vouchers/:id`

Only the owning vendor can update.

```json
{
  "voucher": {
    "name": "updated voucher",
    "active_status": false,
    "rules": {
      "discount_percent": 20
    },
    "valid_until": null
  }
}
```

Responses: `200 OK`, `404 Not Found`, `403 Forbidden`, `422 Unprocessable Content`.

---

### 5. Soft Delete Voucher

`DELETE /v1/events/:event_id/vouchers/:id`

Sets `deleted_at`, returns `204 No Content`.

---

## Data Models

### Voucher

| Field | Type | Description |
| --- | --- | --- |
| `id` | integer | primary key |
| `name` | string | stored uppercase |
| `active_status` | boolean | defaults `true` |
| `public_id` | uuid | attendee-facing identifier |
| `rules` | jsonb | flexible rules payload |
| `valid_until` | timestamp | nullable expiry |
| `event_id` | integer | owning event |
| `vendor_id` | integer | owning vendor (user) |
| `created_at` / `updated_at` | timestamp | lifecycle info |
| `deleted_at` | timestamp | null when active |

### UserVoucher

Tracks voucher claims per attendee ticket.

| Field | Type | Description |
| --- | --- | --- |
| `id` | integer | primary key |
| `ticket_id` | integer | FK to tickets |
| `voucher_id` | integer | FK to vouchers |
| `claimed_at` | timestamp | set when claimed |
| `used_at` | timestamp | optional redemption time |

---

## Business Rules

1. Vendor must be assigned to the event as `event_vendor`.
2. Scope ensures a vendor only reads/updates their own vouchers.
3. Voucher names are uppercased automatically.
4. Soft delete keeps historical data for analytics.
5. `rules` JSON can store any structured configuration.
6. `public_id` used by attendee-facing flows (claims, QR codes).

---

## CLI Examples

```bash
# Create
curl -X POST "https://api.example.com/v1/events/1/vouchers" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"voucher":{"name":"summer sale","rules":{"discount_percent":15}}}'

# List active
curl -X GET "https://api.example.com/v1/events/1/vouchers" \
  -H "Authorization: Bearer <token>"

# Update
curl -X PATCH "https://api.example.com/v1/events/1/vouchers/1" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"voucher":{"active_status":false}}'

# Soft delete
curl -X DELETE "https://api.example.com/v1/events/1/vouchers/1" \
  -H "Authorization: Bearer <token>"
```

---

## Error Codes

| Status | Meaning |
| --- | --- |
| 200 | Success |
| 201 | Created |
| 204 | No Content |
| 400 | Invalid request |
| 401 | Auth required |
| 403 | Forbidden (not vendor / wrong owner) |
| 404 | Resource not found |
| 422 | Validation errors |

---

## See Also

- [`vendor-user-vouchers.md`](vendor-user-vouchers.md) – how claims surface to vendors
- [`user-voucher-public.md`](user-voucher-public.md) – attendee claim flow
