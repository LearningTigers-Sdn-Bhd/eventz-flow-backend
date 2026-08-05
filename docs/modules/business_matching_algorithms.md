# Specification: Business Matching Algorithms for Eventzflow

This document details powerful, industry-standard algorithms that can be implemented in **Eventzflow** to automate and optimize B2B matchmaking, leveraging Eventzflow's existing feature ecosystem (Registration Forms, Event Leads, and Vendor Profiles).

---

## 1. Gale-Shapley (Stable Marriage) Algorithm
**Use Case**: Hosted Buyer Programs, Speed Networking, and Investor-Startup Matching.

In high-value B2B matchmaking, organizers run structured sessions where both sides submit their preferences (e.g. Startups rank their top 10 Investors; Investors rank their top 10 Startups). 
The **Gale-Shapley algorithm** guarantees a matching where no two participants would both prefer to be matched with each other than their current matches.

```
                  RANK PREFERENCES
   ┌──────────────────────────────────────────────┐
   │                                              │
Startups                                      Investors
   │                                              │
   └──────────────► Gale-Shapley ◄────────────────┘
                           │
                           ▼
                    STABLE MATCHES
```

### Eventzflow Schema Integration
* **Exhibitors/Hosts**: Map to `User` or `EventVendor`.
* **Buyers/Attendees**: Map to `Visitor` or `Ticket`.
* Add a preferences table:
  ```ruby
  # app/models/business_matching_preference.rb
  class BusinessMatchingPreference < ApplicationRecord
    belongs_to :event
    belongs_to :participant, polymorphic: true # The user ranking preferences
    belongs_to :target, polymorphic: true      # The ranked partner
    validates :rank, presence: true            # Integer (1 = highest)
  end
  ```

### Algorithm Implementation (Ruby)
```ruby
# app/services/business_matching/stable_matching_service.rb
module BusinessMatching
  class StableMatchingService
    def self.match(event_id)
      # 1. Load preferences
      # 2. Startups (Proposers) propose to their highest-ranked Investor (Accepters).
      # 3. Investors accept proposals provisionally if they prefer the new proposer 
      #    over their current provisional partner.
      # 4. Repeat until all parties are stable matched.
    end
  end
end
```

---

## 2. Hopcroft-Karp (Maximum Bipartite Matching)
**Use Case**: Maximizing total meeting counts under strict slot and table constraints.

If attendees request meetings individually, how does the system schedule them to fit the maximum number of meetings into the event's limited time slots and tables?
The **Hopcroft-Karp algorithm** finds the maximum cardinality matching in a bipartite graph (connecting Requester set $U$ and Receiver set $V$ via meeting requests).

```
   REQUESTRY (U)                        RECEIVER (V)
   ┌───────────┐                        ┌───────────┐
   │ Attendee A├───Requested Meeting───►│ Attendee X│
   │ Attendee B├───Requested Meeting───►│ Attendee Y│
   │ Attendee C├───Requested Meeting───►│ Attendee Z│
   └───────────┘                        └───────────┘
         │                                    │
         └───────────► Hopcroft-Karp ◄────────┘
                            │
                            ▼
                MAXIMUM COMPLETED MEETINGS
```

### Eventzflow Schema Integration
* **Bipartite Nodes**: `requester_id` and `receiver_id` in `BusinessMatchingBooking`.
* **Edges**: Requests with status `Accepted` but not yet assigned to a slot or table.
* **Goal**: Solve table and slot conflicts to schedule the absolute highest number of meetings.

---

## 3. TF-IDF & Cosine Similarity (Semantic Profile Matching)
**Use Case**: Auto-recommending matches by analyzing registration forms.

Eventzflow already collects rich text data via [Registration Forms](file:///Users/orsontamin/Code/Jesselton-Pixel/eventzflow/eventz_flow_api/app/controllers/v1/business_matching/hosts_controller.rb#L213). Visitors input company descriptions, industries, and business needs.
Instead of relying on checkboxes, we can analyze this text using a **TF-IDF** (Term Frequency-Inverse Document Frequency) vectorizer and calculate the **Cosine Similarity** between text descriptions.

$$\text{Cosine Similarity} = \frac{\mathbf{A} \cdot \mathbf{B}}{\|\mathbf{A}\| \|\mathbf{B}\|}$$

### Eventzflow Schema Integration
Extract answers from custom registration forms:
```ruby
# Query answers for visitors
visitor_profiles = Visitor.where(event_id: event_id).map do |v|
  {
    id: v.id,
    text: v.custom_fields_data.values.join(" ") # Concatenate form answers
  }
end
```
By vectorizing the `text` attribute, we get semantic recommendations (e.g. a visitor looking for "high scale mobile apps" automatically matches with an exhibitor listing "iOS and Android software development").

---

## 4. Collaborative Filtering (Lead Capture recommendations)
**Use Case**: Real-time recommendations during live events.

Eventzflow has a powerful **Event Leads** feature (where exhibitors scan visitor QR codes at their booths).
We can use **Item-Based Collaborative Filtering** to recommend matches. If Visitor A scans at Booth X, and history shows 80% of visitors who scanned at Booth X also booked a business matching meeting with Exhibitor Y, we recommend Exhibitor Y to Visitor A via email/push notifications.

```
Visitor A ─── Scanned Booth X ─── (Popular Transition) ──► Suggests meeting Exhibitor Y
```

### Eventzflow Schema Integration
* Uses the [event_leads](file:///Users/orsontamin/Code/Jesselton-Pixel/eventzflow/eventz_flow_api/db/schema.rb#L183) table.
* Uses the [event_vendors](file:///Users/orsontamin/Code/Jesselton-Pixel/eventzflow/eventz_flow_api/db/schema.rb#L523) table.
* Querying association rules:
  ```ruby
  # Identify exhibitors frequently scanned together
  co_occurrences = EventLead.joins(:event_vendor)
                            .group(:leadable_id, :event_vendor_id)
                            # ... Calculate correlation coefficients ...
  ```
