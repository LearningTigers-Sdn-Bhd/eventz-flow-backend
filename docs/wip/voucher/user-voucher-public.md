# Public Voucher Claim API

Attendees use ticket QR codes or links to claim vendor vouchers without authentication.

## Routing

```
/v1/tickets/:ticket_public_id/vouchers/:id
```

- `ticket_public_id`: UUID from `Ticket.public_id`
- `id`: voucher `public_id`

Both routes are public (`authenticate_user!` skipped).

---

## 1. Claim Voucher

`POST /v1/tickets/:ticket_public_id/vouchers/:id`

Creates (or returns) a `UserVoucher` record for the ticket/voucher pair.

**Response 201 (new claim)**

```json
{
  "id": 90,
  "ticket_id": 203,
  "voucher_id": 52,
  "claimed_at": "2025-11-10T07:32:11Z",
  "used_at": null,
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
```

If the ticket already claimed the voucher, the endpoint returns `200 OK` with the existing record.

**Errors**

| Status | Meaning |
| --- | --- |
| `404` | Ticket or voucher not found |
| `422` | Validation errors (duplicate scoped constraint) |

---

## 2. Show Voucher Details

`GET /v1/tickets/:ticket_public_id/vouchers/:id`

Returns the `UserVoucher` entry if the ticket previously claimed the voucher.

```json
{
  "id": 90,
  "ticket_id": 203,
  "voucher_id": 52,
  "claimed_at": "2025-11-10T07:32:11Z",
  "used_at": null,
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
```

**404** responses cover missing ticket, voucher, or user voucher.

---

## Implementation Notes

- `UserVoucher` uniqueness enforces one claim per ticket/voucher pair.
- `claimed_at` is set to `Time.current` for new claims.
- `used_at` remains `null` until redemption workflows are added.
- Vendors see these records via [`vendor-user-vouchers.md`](vendor-user-vouchers.md).
