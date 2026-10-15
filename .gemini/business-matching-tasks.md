# Business Matching Module – Task Checklist (for AI Agent)

Webhook URL (to send request): `https://webhook.saleschatalyst.com/webhook/693921fb30946fd02504c059`

---

## 1. Backend – Event Toggle

* [x] **BM-001 – Add `use_business_matching` column to `events` table**

  * Create migration: add boolean `use_business_matching` with default `true`.

* [x] **BM-002 – Update Event model to include `use_business_matching`**

  * Add to `$fillable` / casts and ensure it’s treated as boolean.

---

## 2. Admin UI – “Use Business Matching” Toggle

* [ ] **BM-010 – Add “Use Business Matching” toggle in Manage Events UI**

  * In Manage Events form, add a new row with a toggle labeled `Use Business Matching`.

* [ ] **BM-011 – Persist “Use Business Matching” toggle to backend**

  * Ensure create/update event APIs save `use_business_matching` to DB via API of update events. Refer to other files for this update event table backend.

* [ ] **BM-012 – Record future logic note for toggle behavior**

  * Hide/disable Business Matching tab when `use_business_matching = false`.

---

## 3. Event Page – Business Matching Tab & Container

* [x] **BM-020 – Add Business Matching tab in Event UI**

  * Add `Business Matching` tab/menu item within each event’s page.

* [x] **BM-021 – Implement Business Matching page container**

  * When tab is clicked, show Business Matching page with title and placeholder area for table (plus loading/error placeholders).

---

## 4. API Integration – Fetch Events from 3rd Party

* [x] **BM-030 – Implement `BusinessMatchingApiClient` service**

  * Create reusable client to call 3rd party API with `event_id` and `action` (e.g. `"Fetch Events"`), returning parsed JSON.
  * Include support for the webhook URL: `https://webhook.saleschatalyst.com/webhook/693921fb30946fd02504c059` where required by the 3rd party.
  * **Enhanced:** Added `user_email`, `user_name`, and `user_id` to the payload for context.

* [x] **BM-031 – Create internal endpoint to fetch business matching events**

  * Route: `GET /api/events/{event}/business-matching/events`.
  * Use `BusinessMatchingApiClient` with action `"Fetch Events"` and return data.
  * **Enhanced:** Added `force_refresh=true` param to bypass cache.

* [x] **BM-032 – Transform 3rd-party events to simplified UI model**

  * From each `output` item, extract:

    * `title` ← `title`
    * `duration` ← `slotDuration`
    * `location` ← `locationLink`
    * `admin_email` ← `adminEmail`
    * `admin_wa_number` ← `adminWaNumber`
    * `id` ← `id` (or `_id`, choose one consistently)
  * Ensure internal API returns only these fields.

* [x] **BM-033 – Render Business Matching events table on front-end**

  * On Business Matching page load, call internal events endpoint.
  * Show table with columns: `Title`, `Duration`, `Location`, `Admin Email`, `Admin WhatsApp`, `Actions (View Availability)`.
  * **Enhanced:** Added "Refresh" button to manually fetch latest data (bypassing cache).
  * **Enhanced:** Implemented caching (30 mins) in frontend and "pending state" in backend to prevent loops.

---

## 5. API Integration – Available Dates & Slots (Calendar View)

* [x] **BM-040 – Create internal endpoint for available dates & slots**

  * Route: `GET /api/business-matching/events/{bm_event_id}/availability`.
  * Call 3rd party API for availability (`Fetch Available Date` / `Fetch Available Slot`).
  * Return JSON shape:

    ```json
    {
      "dates": [
        { "day": "Friday", "date": "12 December 2025", "slots": 16 }
      ]
    }
    ```

* [x] **BM-041 – Add “View Availability” button per row**

  * In events table, add `View Availability` button that calls the availability endpoint with that row’s `bm_event_id`.

* [x] **BM-042 – Render calendar-style view of available dates & slots**

  * Display each date’s `day`, `date`, and total `slots` in a list or grid.
  * Allow user to click/select a date.

* [ ] **BM-043 – Store selected date for future booking flow (placeholder)**

  * When user selects a date, store `bm_event_id` + selected date in state.
  * Show confirmation text (e.g. `You selected [day, date] for [Title]. Booking actions coming soon.`).

---

## 6. Pending – Awaiting JSON Specs

> ❗ **Do not implement yet.** These tasks are blocked until the 3rd party JSON request/response formats are supplied.

* [ ] **PENDING – BM-100 – Create New Booking via 3rd party API**

  * Implement only after receiving JSON spec for create-booking payload and response.

* [ ] **PENDING – BM-101 – Update Booking via 3rd party API**

  * Implement only after receiving JSON spec for update-booking.

* [ ] **PENDING – BM-102 – Fetch Booking Details**

  * Implement only after receiving JSON spec for fetch-booking.

* [ ] **PENDING – BM-103 – Search in Bookings**

  * Implement only after receiving JSON spec for booking search parameters and response.
