# Multi-Day Ticketing

## Overview

EventzFlow supports multi-day event ticketing where:
- Different ticket types can be valid for specific days
- Tickets can be scanned once per valid day (not just once ever)
- System tracks check-ins per day separately

This enables scenarios like:
- 3-day conference with day-specific passes
- Weekend festival with single-day or full-weekend tickets
- Multi-day exhibition with different access levels per day

---

## Table of Contents

1. [Key Concepts](#key-concepts)
2. [Database Schema](#database-schema)
3. [Ticket Type Validity](#ticket-type-validity)
4. [Check-in Flow](#check-in-flow)
5. [API Responses](#api-responses)
6. [Testing](#testing)
7. [Migration Notes](#migration-notes)

---

## Key Concepts

### Ticket Type Validity Dates

Each ticket type can have optional validity dates:
- `valid_from_date` - First day the ticket is valid (null = event start)
- `valid_to_date` - Last day the ticket is valid (null = event end)

Examples:
| Ticket Type | valid_from_date | valid_to_date | Meaning |
|-------------|-----------------|---------------|---------|
| Full Pass | null | null | Valid all event days |
| Day 1 Only | 2026-02-03 | 2026-02-03 | Valid only on Feb 3 |
| Weekend Pass | 2026-02-03 | 2026-02-04 | Valid Feb 3-4 |

### Check-in Records

Check-ins are now stored in a separate `ticket_check_ins` table:
- One record per check-in
- Unique constraint: one check-in per ticket per day
- Tracks who scanned (`scanned_by`) and when (`check_in_at`)

### The "Pernah" Flag

The `tickets.checked_in` boolean remains as a "has ever been checked in" flag:
- Set to `true` on first check-in
- Never reset back to `false`
- Used for quick filtering of "attended" vs "never attended"

---

## Database Schema

### ticket_types table

```
valid_from_date  :date     # First valid day (null = event start)
valid_to_date    :date     # Last valid day (null = event end)
```

### ticket_check_ins table (NEW)

```
id              :bigint    # Primary key
ticket_id       :bigint    # FK to tickets
check_in_at     :datetime  # When checked in
scanned_by_id   :bigint    # FK to users (who scanned)
created_at      :datetime
updated_at      :datetime
```

**Unique Index:** `(ticket_id, DATE(check_in_at))` - prevents duplicate check-ins same day

### tickets table (MODIFIED)

Removed columns:
- `check_in_at` - moved to ticket_check_ins
- `scanned_by_id` - moved to ticket_check_ins

Kept columns:
- `checked_in` - boolean, "has ever been checked in"

---

## Ticket Type Validity

### Model Methods

```ruby
# Check if ticket type is valid for a specific date
ticket_type.valid_for_date?(Date.current)  # => true/false

# Human-readable description
ticket_type.validity_description
# => "Valid all event days"
# => "Valid on February 3, 2026 only"
# => "Valid from Feb 3 to Feb 4, 2026"
```

### Validation Logic

```ruby
def valid_for_date?(date)
  return true if valid_from_date.nil? && valid_to_date.nil?

  from_date = valid_from_date || event.start_date.to_date
  to_date = valid_to_date || event.end_date.to_date

  (from_date..to_date).cover?(date.to_date)
end
```

---

## Check-in Flow

### Scanning a Ticket

1. **Validate ticket type is valid for today**
   - If not valid → Return error with `reason: "wrong_day"`

2. **Check if already checked in today**
   - If yes → Return error with `reason: "duplicate_today"`

3. **Create check-in record**
   - Insert into `ticket_check_ins`
   - Set `checked_in: true` if first time ever

### Model Methods

```ruby
# Check if checked in on a specific date
ticket.checked_in_on?(Date.current)      # => true/false
ticket.checked_in_on?(Date.yesterday)    # => true/false

# Check if checked in today
ticket.checked_in_today?                  # => true/false

# Get check-in record for a date
ticket.check_in_for(Date.current)         # => TicketCheckIn or nil

# All check-ins for a ticket
ticket.check_ins                          # => ActiveRecord::Relation
```

### Timezone Handling

Date comparisons use timezone-aware ranges to ensure correct behavior across timezones:

```ruby
# Correct (timezone-aware)
date = date.to_date
range = date.in_time_zone.beginning_of_day..date.in_time_zone.end_of_day
check_ins.exists?(check_in_at: range)
```

---

## API Responses

### Successful Check-in

```json
{
  "type": "ticket",
  "public_id": "abc-123-def",
  "checked_in": true,
  "check_in_at": "2026-02-03T09:30:00+08:00",
  "ticket_type": {
    "id": 1,
    "name": "Day 1 Pass",
    "valid_from_date": "2026-02-03",
    "valid_to_date": "2026-02-03"
  },
  "scanned_by": {
    "id": 5,
    "full_name": "Staff Name"
  }
}
```

### Error: Wrong Day

```json
{
  "error": "Ticket not valid for today",
  "reason": "wrong_day",
  "type": "ticket",
  "valid_from": "2026-02-04",
  "valid_to": "2026-02-04",
  "validity_description": "Valid on February 4, 2026 only"
}
```

### Error: Already Checked In Today

```json
{
  "error": "Already checked in today",
  "reason": "duplicate_today",
  "type": "ticket",
  "checked_in_at": "2026-02-03T09:30:00+08:00"
}
```

### Ticket List Response

The ticket index endpoint now includes `checked_in_today?`:

```json
{
  "id": 123,
  "public_id": "abc-123",
  "attendee_name": "John Doe",
  "checked_in": true,
  "checked_in_today?": false,
  "ticket_type": {
    "id": 1,
    "name": "2-Day Pass"
  }
}
```

---

## Testing

### Time Travel in Rails Console

```ruby
# Jump to tomorrow
travel_to 1.day.from_now
puts Date.current  # => 2026-02-04

# Jump to specific date
travel_to Date.new(2026, 2, 5)

# Return to real time
travel_back
```

### Test Scenarios

| Scenario | Expected Result |
|----------|-----------------|
| Day 1 ticket scanned on Day 1 | ✅ Success |
| Day 1 ticket scanned on Day 2 | ❌ "Ticket not valid for today" |
| Day 1 ticket scanned twice on Day 1 | ❌ "Already checked in today" |
| 2-Day ticket scanned on Day 1 | ✅ Success |
| 2-Day ticket scanned on Day 2 | ✅ Success |
| 2-Day ticket scanned twice on Day 1 | ❌ "Already checked in today" |

### Creating Test Data

```ruby
# In rails console
event = Event.find(29)
day1_type = event.ticket_types.find_by(name: 'Day 1 Pass')

# Create fresh ticket
ticket = Ticket.create!(
  event: event,
  ticket_type: day1_type,
  attendee_name: 'Test User',
  attendee_email: 'test@example.com',
  status: :purchased,
  payment_status: :paid
)

puts ticket.public_id  # Use this to scan
```

---

## Migration Notes

### Files Changed

**New Files:**
- `app/models/ticket_check_in.rb`
- `db/migrate/XXXXXX_add_valid_dates_to_ticket_types.rb`
- `db/migrate/XXXXXX_refactor_ticket_check_ins.rb`

**Modified Files:**
- `app/models/ticket.rb` - Added check_ins association, helper methods
- `app/models/ticket_type.rb` - Added validity methods
- `app/controllers/v1/scan_controller.rb` - Multi-day check-in logic
- `app/controllers/v1/tickets_controller.rb` - Updated check-in logic
- `app/controllers/v1/public/check_ins_controller.rb` - Updated check-in logic
- `app/controllers/v1/event_analytics_controller.rb` - Scans time series uses TicketCheckIn

### Breaking Changes

| Change | Impact |
|--------|--------|
| `ticket.check_in_at` removed | Use `ticket.check_in_for(date).check_in_at` |
| `ticket.scanned_by` removed | Use `ticket.check_in_for(date).scanned_by` |
| Duplicate scan returns 422 | Frontend should handle "duplicate_today" error |
| Wrong day scan returns 422 | Frontend should handle "wrong_day" error |

### Data Migration

Existing check-in data was migrated:
- `tickets.check_in_at` → `ticket_check_ins.check_in_at`
- `tickets.scanned_by_id` → `ticket_check_ins.scanned_by_id`
- Original `tickets.checked_in` boolean preserved

---

## Related Documentation

- [Ticket Excel Import/Export](./TICKET_EXCEL_IMPORT_EXPORT.md)
- [Event Roles](./EVENT_ROLES.md)
