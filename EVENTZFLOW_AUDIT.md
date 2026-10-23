# EventzFlow Local Audit & Reporting Mirror

This document provides complete context for AI assistants (LLMs) and developers to inspect, audit, query, and generate reports from the EventzFlow production dataset **locally** without touching or risking production.

It follows the mirror architecture established by **WAStays Scout (`wastays-audit`)**: a local PostgreSQL mirror database (`eventzflow_audit`) synced periodically via read-only `pg_dump`.

---

## 1. Architecture & Security Model

```
┌─────────────────────────────────┐           pg_dump (read-only)          ┌──────────────────────────────────┐
│ EventzFlow Production (Docker)  │ ─────────────────────────────────────> │ Local PostgreSQL Mirror          │
│ Server: 46.202.166.235:5434     │                                        │ Database: eventzflow_audit       │
│ Role: claude_auditor (SELECT)   │                                        │ Socket / Port: localhost:5432    │
└─────────────────────────────────┘                                        └──────────────────────────────────┘
                                                                                            ▲
                                                                                            │ Read / Analyze / Report
                                                                                            │
                                                                           ┌──────────────────────────────────┐
                                                                           │ LLM Agent / CLI / Scripts        │
                                                                           │ (Claude, Gemini, Antigravity)    │
                                                                           └──────────────────────────────────┘
```

### Security Certification
- **Production Role:** `claude_auditor` has **strictly `SELECT` permissions**.
- **Denied Operations:** `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE` are certified blocked with `ERROR: permission denied`.
- **Zero Production Footprint:** All reporting aggregations, joins, window functions, and anomaly checks run exclusively on `eventzflow_audit` locally.

---

## 2. Connection Details

### Production Source (Read-Only)
| Attribute | Value |
| :--- | :--- |
| **Host** | `46.202.166.235` |
| **Port** | `5434` (mapped from container 5432) |
| **Database** | `eventz_flow_api_production` |
| **User** | `claude_auditor` |
| **Engine** | PostgreSQL 18.4 (`pgvector:pg18-trixie`) |
| **Client Requirement** | `/opt/homebrew/opt/postgresql@18/bin/` (macOS Homebrew) |

### Local Audit Mirror (Reporting Destination)
| Attribute | Value |
| :--- | :--- |
| **Database Name** | `eventzflow_audit` |
| **Host / Port** | `localhost:5432` |
| **psql Command** | `psql -d eventzflow_audit` |
| **Connection URL** | `postgresql://localhost:5432/eventzflow_audit` |

---

## 3. Refreshing the Mirror (Sync)

To refresh the local mirror with the latest production snapshot, run the automated sync script:

```bash
./bin/sync_audit_db.sh
```

Or manually:

```bash
PGPASSWORD='LTigers82*' /opt/homebrew/opt/postgresql@18/bin/pg_dump \
  "postgresql://claude_auditor@46.202.166.235:5434/eventz_flow_api_production" \
  -Fc -v -f /tmp/eventzflow_mirror.dump

dropdb --if-exists eventzflow_audit && createdb eventzflow_audit
/opt/homebrew/opt/postgresql@18/bin/pg_restore --no-owner --no-privileges -d eventzflow_audit /tmp/eventzflow_mirror.dump || true
psql -d eventzflow_audit -c "ANALYZE;"
rm -f /tmp/eventzflow_mirror.dump
```

---

## 4. MCP Server Setup for AI Coding Agents

To enable LLMs in Claude Code, Gemini Antigravity, or Cursor to query the database directly using tool calls, add this to your MCP configuration (`~/.gemini/config/mcp_config.json` or `.mcp.json`):

```json
{
  "mcpServers": {
    "eventzflow-audit": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres",
        "postgresql://localhost:5432/eventzflow_audit"
      ]
    }
  }
}
```

---

## 5. Domain Schema Map & Core Tables

The database has ~135 tables. The most critical domains for auditing and reports are:

### A. Events & Organizations
- **`events`**: Core event entity (title, dates, status, rfid_mode, scan_mode).
- **`organizations`**: Organizers and tenant groups.
- **`event_locations`**: Check-in gates, zones, meeting halls, and rooms.
- **`event_assignments`**: Staff assignments with per-event roles (`organizer`, `staff`, `scanner`, `exhibitor`).
- **`users`**: System users and profiles.

### B. Tickets, Pricing & Payments
- **`tickets`**: Individual issued tickets (attendee details, check-in status, public_id, custom fields).
- **`ticket_types`**: Ticket tiers per event (VIP, General Admission, Early Bird).
- **`ticket_payments`**: Payment records associated with tickets (amount, gateway, proof, method).
- **`ticket_applications`**: Registration form submissions awaiting review/approval.
- **`pass_bundles`**: Bundled multi-access passes.

### C. Access Control, Gate Scans & RFID
- **`scan_logs`**: Timestamped check-in scans (source: staff scan, self check-in, kiosk, RFID desk).
- **`rfid_bindings`**: Wristband/card RFID UID mapped to tickets or attendees.
- **`rfid_visits`**: Dwell-time and booth/session visit metrics.
- **`rfid_observations`**: Raw antenna read events.
- **`rfid_desk_operations`**: Station/kiosk operator actions.

### D. Exhibitors, Vendors & Booths
- **`exhibitors`**: Participating companies and booth exhibitors.
- **`exhibitor_booths`**: Allocated booth numbers and locations.
- **`exhibitor_team_members`**: Badges and credentials for exhibitor staff.
- **`vendor_profiles`** & **`event_vendors`**: Approved vendors, caterers, and staging partners.

### E. Logs & Communications
- **`email_deliveries`**: Sent invitations, confirmation tickets, reminder emails, delivery status.
- **`user_activities`**: System audit log of user actions.
- **`export_logs`**: History of CSV/Excel data exports.

---

## 6. Critical SQL Modeling Rules for LLMs

When writing queries against `eventzflow_audit`, keep these Rails application patterns in mind:

### 1. Soft Deletes (`deleted_at`)
Rails models use `default_scope { where(deleted_at: nil) }` on `tickets`, `events`, and other core tables.
- **Standard reporting rule:** Always add `WHERE deleted_at IS NULL` to exclude deleted records.
- **Audit rule:** Query `WHERE deleted_at IS NOT NULL` specifically when auditing cancellations, deletions, or data purges.

### 2. Rails Enums (Stored as Integers)
Postgres stores these enum fields as small integers:

* **`tickets.status`**:
  - `0`: `purchased`
  - `1`: `scanned` (legacy flag; real-time check-ins also check `checked_in = true` and `scan_logs`)
  - `2`: `refunded`
  - `3`: `canceled`
  - `4`: `pending_payment`

* **`tickets.payment_status`**:
  - `0`: `pending`
  - `1`: `paid`
  - `2`: `failed`
  - `3`: `refunded_payment`

* **`events.status`**:
  - `0`: `draft`
  - `1`: `published`
  - `2`: `cancelled`
  - `3`: `completed`

* **`scan_logs.source`**:
  - `0`: `staff_scan`
  - `1`: `self_check_in`
  - `2`: `kiosk`
  - `3`: `reprint`
  - `4`: `rfid_desk`

* **`users.role`** (Global system roles):
  - `0`: `org_owner`
  - `1`: `organizer`
  - `2`: `member`
  - `3`: `vendor`
  - `4`: `exhibitor`
  - `5`: `exhibition_contractor`

### 3. Time Zone Handling
- Timestamps are stored in UTC (`timestamp without time zone`).
- Events operate in Malaysia / Singapore time (`Asia/Kuala_Lumpur` / UTC+8).
- For date grouping or daily breakdowns:
  ```sql
  -- Convert UTC to event local time:
  SELECT (scanned_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kuala_Lumpur')::date AS scan_date
  FROM scan_logs;
  ```

### 4. Custom Fields JSONB
Attendee custom details (IC/Passport number, company, designation, dietary needs) are stored in `tickets.custom_fields_data`:
```sql
SELECT
  attendee_name,
  custom_fields_data->>'ic_passport_no' AS ic_passport,
  custom_fields_data->>'company' AS company
FROM tickets
WHERE deleted_at IS NULL;
```

---

## 7. Ready-to-Run Reporting Queries

### Query 1: Event Summary & Attendance Rates
```sql
SELECT
  e.id,
  e.title,
  e.start_date,
  COUNT(t.id) AS total_tickets,
  COUNT(t.id) FILTER (WHERE t.payment_status = 1) AS paid_tickets,
  COUNT(t.id) FILTER (WHERE t.checked_in = true) AS checked_in_count,
  ROUND(
    COUNT(t.id) FILTER (WHERE t.checked_in = true) * 100.0 / NULLIF(COUNT(t.id), 0),
    1
  ) AS attendance_rate_pct
FROM events e
LEFT JOIN tickets t ON t.event_id = e.id AND t.deleted_at IS NULL
WHERE e.deleted_at IS NULL
GROUP BY e.id, e.title, e.start_date
ORDER BY e.start_date DESC;
```

### Query 2: Ticket Type & Revenue Breakdown for an Event
```sql
SELECT
  tt.name AS ticket_tier,
  COUNT(t.id) AS tickets_sold,
  COALESCE(SUM(tp.amount), 0) AS total_collected,
  COUNT(t.id) FILTER (WHERE t.checked_in = true) AS checked_in
FROM ticket_types tt
JOIN tickets t ON t.ticket_type_id = tt.id AND t.deleted_at IS NULL
LEFT JOIN ticket_payments tp ON tp.ticket_id = t.id AND tp.status = 'paid'
WHERE tt.event_id = :event_id
GROUP BY tt.id, tt.name
ORDER BY tickets_sold DESC;
```

### Query 3: Check-in Peak Hours & Traffic by Location
```sql
SELECT
  COALESCE(el.name, 'Main Entrance / General') AS gate_location,
  DATE_TRUNC('hour', sl.scanned_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kuala_Lumpur') AS hour_slot,
  COUNT(*) AS scans_count
FROM scan_logs sl
LEFT JOIN event_locations el ON el.id = sl.event_location_id
WHERE sl.event_id = :event_id
GROUP BY 1, 2
ORDER BY hour_slot ASC;
```

### Query 4: Audit Discrepancies (Unpaid Checked-In Tickets)
```sql
SELECT
  t.id AS ticket_id,
  t.attendee_name,
  t.attendee_email,
  e.title AS event_title,
  t.payment_status,
  t.checked_in,
  t.check_in_at
FROM tickets t
JOIN events e ON e.id = t.event_id
WHERE t.deleted_at IS NULL
  AND t.checked_in = true
  AND t.payment_status != 1 -- Not paid
ORDER BY t.check_in_at DESC;
```

---

## 8. PII Masking Guidelines

When generating public reports, CSVs, or LLM summaries:
- Mask phone numbers: `+6012****789`
- Mask emails: `j***n@example.com`
- Mask IC / Passports: `******-12-3456`
- Retain aggregate figures, counts, monetary totals, and category distributions.
