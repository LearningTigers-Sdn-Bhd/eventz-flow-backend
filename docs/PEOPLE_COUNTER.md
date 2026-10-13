# People counter

Live and event-wide visitor counts per hall, level and event. The counters and
their data live in a separate service; EventzFlow stores only which counter
each hall reads from and asks for the numbers on demand.

In the panel: **Event → People Counter**. Two tabs:

- **Live counts**: the data. Anyone who can view the event (organizers included).
- **Settings**: counter connection + halls. **Org owners only.**

## Setup (org owner, per event)

1. In the counter service, open **API keys** and create a key. Give each system
   its own key and an expiry. The key is shown once; copy it.
2. In EventzFlow open the event's **People Counter → Settings**, enter the
   service URL and the key, press **Test connection**, then **Save**.
3. Add the event's halls (**Add Hall**), optionally with a level, and pick each
   hall's counter from the dropdown (it lists the venues on that service).

The key is stored encrypted and is never sent back to the browser; the page
only shows its first characters. To rotate: create a new key in the counter
service, save it here, then revoke the old one. A revoked or expired key makes
halls show "Counter unreachable" until it is replaced.

### Optional server-wide fallback

If an event has no connection of its own, the backend uses these (production:
real env vars; development: `.env`). Handy for one shared counter service; they
are not needed once events have their own connection.

| Variable | Example |
|----------|---------|
| `PEOPLE_COUNTER_URL` | `https://counters.example.com` |
| `PEOPLE_COUNTER_API_TOKEN` | an API key created in the counter service |

## Model

- `event_halls` (`event_id`, `name`, `floor`, `counter_venue_id`, `position`).
  Independent of `EventLocation` (ticket scanning). `floor` groups halls into
  levels. `counter_venue_id` is the venue id on the counter service; the same
  venue can be reused by many events.
- `people_counter_connections` (`event_id` unique, `base_url`, `api_key`
  encrypted). One per event.

## Endpoints (all under `/v1`)

| Endpoint | Who |
|----------|-----|
| `GET /events/:event_id/event_halls`, `…/event_halls/headcount` | anyone who can view the event |
| `POST/PUT/DELETE /events/:event_id/event_halls[/:id]` | org owners |
| `GET/PUT/DELETE /events/:event_id/people_counter_connection` | org owners |
| `POST /events/:event_id/people_counter_connection/test` | org owners (always 200; the body says ok / unauthorized / unreachable) |
| `GET /events/:event_id/people_counter/venues` | org owners (feeds the hall dropdown) |

Everything that changes how an event reads counts is org-owner-only. A
non-owner gets 403. The counter service rejecting a key is never returned as
401/403 by these endpoints: the panel treats those as "session expired".

## Safety

- The URL is user-entered, so outside development the server refuses addresses
  that resolve to private or local networks (`AiIntegrations::NetworkGuard`,
  shared with the AI integrations) and pins the connection to the checked address.
  Production URLs must be `https`.
- Saving with a blank key keeps the saved one, but only while the URL is
  unchanged; changing the URL requires typing the key again, so the saved key
  can never be sent to a new address.

## How numbers are computed

`PeopleCounter::EventHeadcount` (cached 15 s per event, cleared when the
connection changes):

- Live "inside now", today's in/out and capacity come from one venue-list call.
- Whole-event in/out come from a whole-day window over the event's
  `start_date`..`end_date` (UTC+8, same as the counters). One call per linked hall.
- Levels and the event total are sums of their halls. A hall that can't be read
  (`unlinked`, `not_found`, `unavailable`) is left out of sums, never counted as zero.
- The payload carries `configured`: false when the event has no connection and no
  server-wide fallback, so the panel can say "not set up" instead of "unreachable".

## Known limits

- The window is whole days, not exact start/end times: back-to-back events in
  the same hall on the same day share that day's numbers.
- The saved key is per event, so a counter service shared by several events
  needs the key entered for each (a "copy from another event" shortcut could be added).
