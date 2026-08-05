# Specification: Advanced B2B Matchmaking Improvements

This document outlines the product features, data architecture, and algorithms required to extend the in-house business matching system to cover **90% of B2B matchmaking events** (e.g. speed networking, hosted buyer programs, investor-startup matching, and B2B trade shows).

---

## 1. Core Limitations of Current Setup (Why it only covers ~30%)
The current system operates on a **Host-Visitor booking model** (similar to Calendly):
* Visitor views a host's open calendar.
* Visitor books a slot, which is auto-confirmed or enters a single status flag.
* There is no mechanism to profile attendees, auto-suggest matches, handle physical seating resource conflicts (tables), or support peer-to-peer (Attendee-to-Attendee) matching.

---

## 2. Essential Modules for 90% Matchmaking Events

To satisfy the operational needs of 90% of B2B matching events, the system needs to support these five modules:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Advanced B2B Matchmaking                          │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  Smart Matching │         │ Request-Accept  │         │  Table/Seating  │
│  & Recommendations│       │      Flow       │         │   Allocation    │
└─────────────────┘         └─────────────────┘         └─────────────────┘
         │                           │
         └─────────────┬─────────────┘
                       ▼
            ┌─────────────────────┐
            │     Peer-to-Peer    │
            │     Matchmaking     │
            └─────────────────────┘
```

---

## 3. Module Specifications & Implementation

### Module A: Peer-to-Peer Matchmaking (Attendee-to-Attendee)
Instead of restricting matchmaking to a few pre-assigned "Hosts" and many anonymous "Visitors", allow all registered ticket holders or exhibitors to act as potential hosts and participants.

#### 1. Data Schema Updates
Extend the participant roles or link matchmaking directly to the `Ticket` or `Visitor` records.
```ruby
# app/models/business_matching_participant.rb
class BusinessMatchingParticipant < ApplicationRecord
  belongs_to :event
  belongs_to :registerable, polymorphic: true # Links to User, Visitor, or Ticket
  
  has_many :availabilities, class_name: 'BusinessMatchingAvailability', foreign_key: :participant_id
  has_many :sent_requests, class_name: 'BusinessMatchingBooking', foreign_key: :requester_id
  has_many :received_requests, class_name: 'BusinessMatchingBooking', foreign_key: :receiver_id
end
```

---

### Module B: Profile Tag-Based Matching & Recommendations (Smart Match)
Matchmaking events succeed when participants are introduced to high-value connections. By introducing **"Offerings"** (What I Have) and **"Interests"** (What I Seek) tags, the engine can rank compatibility.

#### 1. Schema Extensions
```ruby
# JSON structure inside BusinessMatchingParticipant
# :profile_data => {
#   offering_tags: ["SaaS", "Seed Capital", "Web Development"],
#   interest_tags: ["AI Startups", "Healthcare Tech", "Marketing Partners"]
# }
```

#### 2. Recommendation Matching Algorithm
Implement a Jaccard Similarity index query in Rails to compute compatibility score:
$$\text{Match Score} = \frac{|P_A.\text{offerings} \cap P_B.\text{interests}| + |P_B.\text{offerings} \cap P_A.\text{interests}|}{|P_A.\text{tags} \cup P_B.\text{tags}|}$$

```ruby
# app/services/business_matching/matching_engine.rb
module BusinessMatching
  class MatchingEngine
    def self.recommend_matches(participant, limit = 10)
      # Compare tag intersections in PostgreSQL via JSONB containment queries
      # and return prioritized matches sorted by highest overlap score.
    end
  end
end
```

---

### Module C: Double-Sided Request-Accept-Decline Flow
B2B meetings are rarely auto-confirmed. They require validation from the recipient.
1. **State Machine**:
   ```
   [ Requested ] ──► [ Accepted ] ──► [ Scheduled ] (Slot & Table assigned)
        │                 │
        ▼                 ▼
   [ Declined ]      [ Cancelled ]
   ```
2. **Mutual Availability Matcher**:
   When A requests a meeting with B, B accepts. The system looks up overlapping free times between A's calendar and B's calendar, suggesting only mutually free slots to finalize the schedule.

---

### Module D: Dynamic Table & Seating Allocation (Table Conflict Solver)
Organizers have a limited number of physical meeting tables (e.g. 20 tables at the venue). Two meetings cannot occur at the same table at the same time.

#### 1. Table Registry Model
```ruby
# app/models/business_matching_table.rb
class BusinessMatchingTable < ApplicationRecord
  belongs_to :event
  validates :table_number, uniqueness: { scope: :event_id }
end
```

#### 2. Allocation Algorithm (Auto-Assignment)
When a meeting booking is finalized at `booking_date` and `booking_time`:
1. Find all `BusinessMatchingTable` records for the event.
2. Query which tables are already occupied during that time slot:
   ```ruby
   occupied_table_ids = BusinessMatchingBooking
                          .where(booking_date: date, booking_time: time, status: 'Confirmed')
                          .pluck(:table_id)
   ```
3. Assign the first available table:
   ```ruby
   available_table = BusinessMatchingTable.where.not(id: occupied_table_ids).first
   if available_table
     booking.update!(table: available_table)
   else
     raise StandardError, "Resource Conflict: All tables are occupied at this slot."
   end
   ```

---

### Module E: Event Operational Phases (Timeline Window)
Give organizers the tools to open and close features based on the event timeline.

1. **Profile Setup Phase**: Attendees register and enter their offering/interest tags. Booking is disabled.
2. **Meeting Request Phase**: Attendees browse matches and send requests. Times are locked in as accepted.
3. **On-Site Phase**: Attendees follow their personal schedule. Walk-ins can book remaining open slots instantly on-site via QR codes.

---

## 4. Summary of Code changes needed to achieve 90% coverage
To take our current staging code (`feature/in-house-business-matching`) and make it fully generalized, we would:
1. **Introduce a `Participant` mapping table** linking users/visitors to the matching engine.
2. **Upgrade the Slot Engine** to calculate intersections of two participants' availability, rather than just host availability.
3. **Add `BusinessMatchingTable` model** and hook it into booking confirmation to assign tables dynamically.
4. **Upgrade Frontend Dialogs** to render a "Send Meeting Request" form and a "Received Invites" list, allowing double-sided approval directly in the attendee portal.

---

## 5. Participant Experience, Accounts, and Unified Role Model

### A. Host "What I Have / What I Seek" (Double-Sided Profiling)
Yes! To facilitate smart recommendations, **Hosts** (exhibitors/sponsors) will enter both their offerings ("What I Have") and their interests ("What I Seek"). 
* *Example*: Host A offers "Cloud Analytics Platforms" (What I Have) and seeks "Fintech Channel Partners" (What I Seek).

### B. Participant Accounts & "Accountless" Onboarding (UX Friction Removal)
Requiring participants (buyers/guests) to register a separate password-locked account for matchmaking results in high friction and low engagement.
* **Solution: Secure Magic Link Token (No Account Registration Required)**
  1. When a participant registers or buys a ticket, Eventzflow creates a `Visitor` or `Ticket` record.
  2. The backend generates a secure, unique, and long-lived **Secure Token** (`magic_token`) assigned to their visitor record.
  3. The matchmaking invitation email/WhatsApp includes their personal access link:
     `https://eventzflow.com/event/:event_slug/portal?token=:magic_token`
  4. Clicking this link automatically authenticates them into their **Attendee Matchmaking Portal**, allowing them to instantly update their offering/seeking tags, view recommendations, send requests, and accept invites without signing up.

### C. Host-to-Host (Exhibitor-to-Exhibitor) Meetings
In large trade shows, exhibitors frequently want to match and meet with other exhibitors (e.g. suppliers matching with distributors).
* **Solution: Unified Participant Model**
  Rather than keeping Hosts and Visitors in strictly separated database tables, we unify them under a single `BusinessMatchingParticipant` polymorphic record.
  * Both an `Exhibitor` (Host) and `Visitor` (Guest) map to a `Participant`.
  * Each `Participant` has offering tags, seeking tags, and an active schedule.
  * The organizer can configure an **Interaction Matrix** for the session:
    ```json
    {
      "visitor_to_exhibitor": true,
      "exhibitor_to_exhibitor": true,  // Enables Host-to-Host matching!
      "visitor_to_visitor": false
    }
    ```
  * The matching engine reads this matrix to allow or restrict search results and meeting requests.

