# Vendor User Vouchers Endpoint

Vendors can review ticket-level voucher usage for their booth via a dashboard list.

## Endpoint

`GET /v1/events/:event_id/vendors/:id/user_vouchers`

## Authentication & Authorization

- Requires Bearer token.
- Caller must be the assigned `event_vendor` for this record (`EventVendor.vendor_id` matches the authenticated user). The `:id` path param is the `EventVendor.id`.

## Response

```json
[
  {
    "id": 18,
    "ticket_id": 203,
    "voucher_id": 52,
    "claimed_at": "2025-11-10T07:32:11Z",
    "used_at": null,
    "ticket": {
      "id": 203,
      "public_id": "c0f97c93-d93c-4f13-9dd7-0fbf978bcf4a",
      "attendee_name": "Jamie Doe",
      "attendee_email": "jamie@example.com"
    },
    "voucher": {
      "id": 52,
      "name": "DISCOUNT10",
      "public_id": "2a9f6bf6-0590-4c9b-a7b5-4d4b8f5a6d77",
      "active_status": true,
      "rules": {
        "discount_percent": 10
      },
      "valid_until": "2025-12-31T23:59:59Z"
    }
  }
]
```

Entries are ordered by `claimed_at DESC NULLS LAST` so the newest claims appear first, followed by unclaimed (null) entries.

## Error Codes

| Status | Meaning |
| --- | --- |
| `404 Not Found` | Event missing |
| `403 Forbidden` | User not assigned as vendor |
| `401 Unauthorized` | Missing/invalid token |

## Usage Tips

- Combine with [`voucher-analytics.md`](voucher-analytics.md) for aggregate reporting.
- `ticket.public_id` lets support teams cross-reference public attendees.
- `used_at` remains `null` until redemption flows are implemented.
