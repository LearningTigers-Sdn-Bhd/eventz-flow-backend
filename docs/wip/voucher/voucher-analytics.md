# Voucher Analytics API

Vendors can view engagement, claim, and redemption metrics for their vouchers within an event.

## Base URL

```
/v1/events/:event_id/vendors/:id/analytics
```

The `:id` parameter is the `EventVendor.id` (not the vendor user ID).

## Authentication & Authorization

- Requires Bearer token.
- Caller must be the assigned `event_vendor` for this record (`EventVendor.vendor_id` matches the authenticated user).

---

## Endpoints

### 1. Engagement Count (Today)

`GET /v1/events/:event_id/vendors/:id/analytics/engagement_count`

Counts distinct `ticket_id` in `UserEngageVendor` for the vendor within the event.

**Response 200**

```json
{
  "event_id": 42,
  "vendor_id": 7,
  "event_vendor_id": 15,
  "engagement_count": 45
}
```

---

### 2. Claimed Count (Today)

`GET /v1/events/:event_id/vendors/:id/analytics/claimed_count`

Counts distinct ticket claims (`UserVoucher.claimed_at`) occurring today.

**Response 200**

```json
{
  "event_id": 42,
  "vendor_id": 7,
  "event_vendor_id": 15,
  "claimed_count": 32
}
```

---

### 3. Redeemed Count (Today)

`GET /v1/events/:event_id/vendors/:id/analytics/redeemed_count`

Counts distinct ticket redemptions (`UserVoucher.used_at`) occurring today.

**Response 200**

```json
{
  "event_id": 42,
  "vendor_id": 7,
  "event_vendor_id": 15,
  "redeemed_count": 12
}
```

---

### 4. Weekly Metrics

`GET /v1/events/:event_id/vendors/:id/analytics/weekly_metrics`

Returns daily counts for the past 7 days for engagement, claims, and redemptions.

**Response 200**

```json
{
  "event_id": 42,
  "vendor_id": 7,
  "event_vendor_id": 15,
  "weekly_metrics": {
    "engagement": [
      { "date": "2025-11-04", "count": 5 },
      { "date": "2025-11-05", "count": 8 },
      { "date": "2025-11-06", "count": 12 },
      { "date": "2025-11-07", "count": 15 },
      { "date": "2025-11-08", "count": 18 },
      { "date": "2025-11-09", "count": 22 },
      { "date": "2025-11-10", "count": 25 }
    ],
    "claimed": [
      { "date": "2025-11-04", "count": 3 },
      { "date": "2025-11-05", "count": 6 },
      { "date": "2025-11-06", "count": 9 },
      { "date": "2025-11-07", "count": 11 },
      { "date": "2025-11-08", "count": 14 },
      { "date": "2025-11-09", "count": 18 },
      { "date": "2025-11-10", "count": 21 }
    ],
    "redeemed": [
      { "date": "2025-11-04", "count": 1 },
      { "date": "2025-11-05", "count": 2 },
      { "date": "2025-11-06", "count": 4 },
      { "date": "2025-11-07", "count": 5 },
      { "date": "2025-11-08", "count": 7 },
      { "date": "2025-11-09", "count": 9 },
      { "date": "2025-11-10", "count": 12 }
    ]
  }
}
```

---

## Data Sources

| Metric | Table | Filters |
| --- | --- | --- |
| Engagement | `user_engage_vendors` | `vendor_profile.id` (found via group), `DATE(created_at)` |
| Claimed | `user_vouchers` | `vouchers.event_id`, `vouchers.vendor_id`, `DATE(claimed_at)` |
| Redeemed | `user_vouchers` | `vouchers.event_id`, `vouchers.vendor_id`, `DATE(used_at)` |

---

## Error Codes

| Status | Meaning |
| --- | --- |
| `404 Not Found` | Event or event vendor not found |
| `403 Forbidden` | User not assigned as vendor |
| `401 Unauthorized` | Missing/invalid token |

---

## Usage Tips

- Combine with [`vendor-user-vouchers.md`](vendor-user-vouchers.md) for detailed ticket-level data.
- Weekly metrics include the current day.
- All dates are in UTC.
