# Mission Rewards Feature Specification

## Overview

A gamification system that allows event organizers to create missions for participants (visitors/ticket holders) who can complete tasks to earn reward draws. Winners can redeem their rewards by presenting QR codes to organizers.

---

## User Roles & Capabilities

### Admin
- Enable and manage missions (By creating or editing the mission session)
- Define the tasks completion criteria for accessing reward draws

### Visitor/Ticket Holder (Participant)
- View and complete assigned task
- Draw rewards when requirements are met based on Task Group
- Generate reward QR codes for redemption
- Track personal progress and won rewards

### Organizer
- Scan participant reward QR codes
- Mark rewards as redeemed
- Verify reward authenticity
- Manage winner records

---

## Business Rules

### Mission Requirements
- Organizers can designate specific missions.
- This is like a bingo system, where the organizer puts 3-4 tasks per group. When user completes all tasks in that group, the group will indicate user is eligible to draw.
- Task grouping enables organizer to create repeatable missions and rewards.
- One draw per task group only - once claimed, that group cannot be drawn from again.

### Mission Session Status
- **Draft (0)**: Session is being configured, not visible to participants
- **Published (1)**: Session is live and accessible to participants
- When published, the following edits are prevented:
  - Changing task `task_group` assignments
  - Deleting rewards that have already been won
  - Editing `total_reward` to be less than `received_count`
  - Deleting tasks

### Reward Distribution Rules
- `max_reward_per_participant` is enforced globally across all task groups
- If a participant has already won Reward A from Task Group 1, Reward A will not appear in Task Group 2 draw pool
- Rewards are filtered by validity period (`start_datetime` and `end_datetime`) at draw time
- If rewards are depleted after temp token is issued, draw will fail with proper error message

### Constraints
- Participants (visitors/ticket holders) are not permanent users
- No dedicated User model required for participants
- Participant identification via ticket ID or visitor ID depending on event configuration
- Participants cannot access mission sessions in draft status
- Soft-deleted sessions prevent reward redemption

---

## Technical Implementation Plan

### Participant Flow Endpoints

#### 1. Get Mission Progress
```
GET /events/{event_id}/mission-rewards/participants/{participant_id}
```

**Purpose:** Retrieve participant's mission progress and eligibility

**Access Control:** Only accessible when mission session status is published (status: 1)

**Process:**
1. Verify mission session is published (status: 1), return error if draft
2. Retrieve event mission session and available rewards
3. Detect event configuration (`use_ticket` flag)
   - If `true`: Query using ticket `public_id` or `id`
   - If `false`: Query using visitor `public_id` or `id`
4. Verify participant existence
5. Fetch participant's won rewards and which `task_group` is claimed from `ParticipantReward`
6. Evaluate task requirements against participant stats using `MissionTaskConditionService`
7. Group tasks by `task_group` and determine status:
   - `"claimed"`: task_group exists in ParticipantReward
   - `"eligible"`: service returns eligible: true AND no claim record
   - `"locked"`: service returns eligible: false

**Response Payload:**
```json
{
  "event": {
    "title": "string"
  },
  "mission_session": {
    "title": "string",
    "status": "integer"
  },
  "task_groups": [
    {
      "task": "object",
      "status": "locked|eligible|claimed",
      "current_value": "number",
      "required_value": "number"
    }
  ],
  "rewards": "array",
  "participant_reward_count": "number"
}
```

#### 2. Get Participant Rewards
```
GET /events/{event_id}/mission-rewards/participants/{participant_id}/rewards
```

**Purpose:** Retrieve all rewards won by participant

**Access Control:** Only accessible when mission session status is published (status: 1)

**Response Payload:**
```json
{
  "event": {
    "title": "string"
  },
  "mission_session": {
    "title": "string",
    "status": "integer"
  },
  "participant_rewards": "array"
}
```

#### 3. Check Draw Eligibility
```
GET /events/{event_id}/mission-rewards/participants/{participant_id}/draw?task_group={task_group}
```

**Purpose:** Verify eligibility and prepare reward draw

**Access Control:** Only accessible when mission session status is published (status: 1)

**Process:**
1. Verify mission session is published (status: 1)
2. Verify participant meets all task requirements for specified `task_group`
   - Fetch tasks based on `task_group` column
   - Use `MissionTaskConditionService` to evaluate all tasks in group
3. Check participant has not already claimed from this task_group
4. Filter available rewards based on:
   - `total_reward > received_count` (availability)
   - `max_reward_per_participant` limit (global across all task groups)
   - Reward validity period: `start_datetime <= NOW() <= end_datetime`
   - Exclude rewards participant has already won (if max_reward_per_participant enforced)
5. Generate temporary participant token for security
6. Return eligible rewards and draw configuration

**Response Payload:**
```json
{
  "access": "boolean",
  "event": {
    "title": "string"
  },
  "mission_session": {
    "title": "string",
    "status": "integer",
    "draw_styles": "string",
    "wrapper_background": "string"
  },
  "rewards": "array",
  "participant_temp_token": "string"
}
```

#### 4. Execute Reward Draw
```
POST /events/{event_id}/mission-rewards/participants/{participant_id}/draw
```

**Purpose:** Record reward selection and generate redemption code

**Access Control:** Only accessible when mission session status is published (status: 1)

**Request Payload:**
```json
{
  "reward_id": "integer",
  "participant_temp_token": "string",
  "task_group": "integer"
}
```

**Process:**
1. Verify mission session is published (status: 1)
2. Validate `participant_temp_token` exists and matches task_group
3. Verify reward still available:
   - Check `total_reward > received_count`
   - Check reward validity period
   - Check participant hasn't exceeded `max_reward_per_participant`
   - Return error if reward depleted or invalid
4. Create `ParticipantReward` record
5. Increment reward `received_count`
6. Delete temporary token
7. Return reward details with QR code data

---

### Organizer Flow Endpoints

#### 1. Mission Session Management
```
POST   /events/{event_id}/mission-rewards          # Create (Enable feature)
GET    /events/{event_id}/mission-rewards          # Retrieve session
PATCH  /events/{event_id}/mission-rewards          # Edit session
DELETE /events/{event_id}/mission-rewards          # Soft delete (Disable feature)
POST   /events/{event_id}/mission-rewards/restore  # Restore (Enable feature)
DELETE /events/{event_id}/mission-rewards/force    # Force delete (Clear all data)
```

**Terminology:**
- **Create(Enable)**: Initialize mission-rewards feature for the event with status draft (0).
- **Edit**: Update mission session configuration. When status is published (1), prevent critical changes.
- **Soft Delete(Disable)**: Disable feature while preserving all data. Prevents participant access and redemption.
- **Restore(Enable)**: Re-enable previously disabled feature.
- **Force Delete(Clear Data)**: Permanently remove all mission-rewards data including tasks, rewards, participant records, and temp tokens. Follow the same policies as event deletion policy.

**Notes:** Please refer to the `lucky-draw-session` controllers on how they handle draw_styles and wrapper_background JSONB.

**Create/Update Payload:**
```json
{
  "title": "string",
  "status": "integer",
  "draw_styles": "object",
  "wrapper_background": "object"
}
```

#### 2. Task Management (Full CRUD)
```
GET     /events/{event_id}/mission-rewards/tasks
GET     /events/{event_id}/mission-rewards/tasks/{id}
POST    /events/{event_id}/mission-rewards/tasks
PATCH   /events/{event_id}/mission-rewards/tasks/{id}
DELETE  /events/{event_id}/mission-rewards/tasks/{id}
```

**Create/Update Payload:**
```json
{
  "mission_session_id": "integer",
  "name": "string",
  "model": "enum(voucher, stamps)",
  "condition": "integer",
  "require": "float|null",
  "task_group": "integer"
}
```

**Validation Rules:**
- Use `MissionTaskConditionService.validate_condition_exists(model, condition)` to validate payload
- When mission session status is published (1):
  - Prevent changes to `task_group`
  - Prevent task deletion
  - Other fields can be updated

**Condition Field Logic:**
- The `condition` field stores an integer code that maps to specific validation logic for each model type
- Use `MissionTaskConditionService.validate_condition_exists(model, condition)` to validate the payload
- This ensures only valid model-condition combinations are accepted
- Example: If organizer submits `{model: "voucher", condition: 99}` and condition 99 doesn't exist for voucher model, the request will be rejected
- Returns boolean: `true` if valid, `false` if invalid combination

#### 3. Reward Management (Full CRUD)
```
GET     /events/{event_id}/mission-rewards/rewards
GET     /events/{event_id}/mission-rewards/rewards/{id}
POST    /events/{event_id}/mission-rewards/rewards
PATCH   /events/{event_id}/mission-rewards/rewards/{id}
DELETE  /events/{event_id}/mission-rewards/rewards/{id}
```

**Purpose:** Manage rewards available for participant draws

**Validation Rules:**
- When mission session status is published (1):
  - Prevent deletion if `received_count > 0`
  - Prevent reducing `total_reward` below current `received_count`

#### 4. Reward Redemption
```
POST /events/{event_id}/mission-rewards/rewards/{id}/redeem
```

**Purpose**: Process participant reward redemption via QR code scanning

**Request Payload:**
```json
{
  "participant_reward_public_id": "string"
}
```

**Process:**
1. Verify mission session is not soft-deleted
2. Validate participant reward QR code exists
3. Verify reward authenticity and belongs to this event
4. Check reward not already redeemed
5. Mark reward as redeemed (`is_redeemed: true`)
6. Increment reward `redeemed_count`
7. Return redemption confirmation

---

## Database Schema

### MissionSession
Represents the overall mission-rewards system for an event (similar to LuckyDrawSession).

**Fields:**
- `id` (primary key)
- `event_id` (foreign key, unique - one mission session per event)
- `title` (string)
- `status` (integer, default: 0) - 0: draft, 1: published
- `draw_styles` (JSONB)
- `wrapper_background` (JSONB)
- Timestamps

**Note:** One event has one mission-rewards feature enabled

---

### MissionTask
Individual tasks participants must complete to earn reward draws.

**Fields:**
- `id` (primary key)
- `mission_session_id` (foreign key)
- `name` (string)
- `model` (enum: 'voucher', 'stamps')
- `condition` (integer) - Maps to validation logic
- `require` (float, nullable) - Required completion threshold
- `task_group` (integer, default: 1) - Groups related tasks
- Timestamps

---

### MissionReward
Rewards available in the draw.

**Fields:**
- `id` (primary key)
- `mission_session_id` (foreign key)
- `name` (string)
- `description` (text, nullable)
- `reward_code` (string, nullable)
- `reward_value` (text)
- `start_datetime` (datetime)
- `end_datetime` (datetime)
- `total_reward` (integer, nullable) - null = unlimited
- `max_reward_per_participant` (integer, nullable) - null = unlimited
- `received_count` (integer, default: 0)
- `redeemed_count` (integer, default: 0)
- Timestamps

---

### ParticipantTempToken
Temporary security tokens for reward draw transactions.

**Fields:**
- `uuid` (primary key)
- `task_group` (integer)
- `ticket_id` (foreign key, nullable)
- `visitor_id` (foreign key, nullable)
- Timestamps

**Purpose:** Prevent unauthorized reward draws and ensure single-use draw sessions. Token is deleted upon successful reward claim.

**Constraints:**
- Database-level CHECK constraint: Either `ticket_id` OR `visitor_id` must be present (XOR constraint)

---

### ParticipantReward
Records of rewards won by participants.

**Fields:**
- `id` (primary key)
- `ticket_id` (foreign key, nullable)
- `visitor_id` (foreign key, nullable)
- `reward_id` (foreign key)
- `participant_reward_uuid` (uuid, unique) - Used for QR code generation
- `is_redeemed` (boolean, default: false)
- `task_group` (integer)
- Timestamps

**Constraints:**
- Database-level CHECK constraint: Either `ticket_id` OR `visitor_id` must be present (XOR constraint)
- Database-level partial unique index to prevent duplicate rewards per participant per task_group

---

## Service Classes

### MissionTaskConditionService

**Purpose:** Centralized logic for evaluating task completion conditions

**Location:** `app/services/mission_task_condition_service.rb`

**Public Methods:**

#### 1. `validate_condition_exists(model, condition)`

**Purpose:** Verify that a condition code is valid for the specified model type

**Parameters:**
- `model` (String) - The model type ('voucher', 'stamps', etc.)
- `condition` (Integer) - The condition code to validate

**Returns:** Boolean indicating if condition exists for the model

**Usage:** Called during task creation/update to ensure valid condition-model combinations before saving to database

---

#### 2. `execute_condition(model:, condition:, require: nil, ticket_id: nil, visitor_id: nil)`

**Purpose:** Execute condition validation logic against participant data

**Parameters:**
- `model` (String) - The model type to check against
- `condition` (Integer) - The condition code to execute
- `require` (Float|nil) - The required threshold value
- `ticket_id` (Integer|nil) - Participant's ticket ID
- `visitor_id` (Integer|nil) - Participant's visitor ID

**Returns:**
```json
{
  "eligible": true,
  "current_value": 5,
  "required_value": 3
}
```

**Usage:** Called during participant progress evaluation and draw eligibility checks

**Error Handling:**
- Raises custom error if condition doesn't exist for model
- Raises custom error if neither ticket_id nor visitor_id is valid
- Returns structured error in response hash for business logic failures

---

#### 3. `model_condition_select_values`

**Purpose:** Provide form select options for all available model-condition combinations

**Parameters:** None

**Returns:**
```json
{
  "voucher": [
    {
      "label": "Redeemed (Complete)",
      "value": 1,
      "description": "Checks if voucher redemption status is complete"
    },
    {
      "label": "Redeemed (Count)",
      "value": 2,
      "description": "Counts number of redeemed vouchers"
    }
  ],
  "stamps": [
    {
      "label": "Collected (Equal)",
      "value": 0,
      "description": "Checks if stamps collected equals requirement"
    },
    {
      "label": "Collected (More)",
      "value": 1,
      "description": "Checks if stamps collected is more than requirement"
    }
  ]
}
```

**Usage:**
- Called by GET endpoint to populate task creation/edit form
- Provides user-friendly labels and descriptions for condition selection
- Groups conditions by model type for better UX
- Response should be cached as values are static

---

**Implementation Notes:**

- **Service Object Pattern**: Implemented as a class with class methods
- **Condition Registry Pattern**: Service maintains internal constant/hash mapping condition codes to validation logic per model
- **Extensibility**: New conditions can be added to the registry without modifying existing validation code
- **Memoization**: Consider memoizing `model_condition_select_values` results as they're static

**Service Structure:**
- Custom error classes defined within service for specific error handling
- Condition registry as frozen constant containing model-condition mappings
- Each condition maps to a validator method that performs the actual check
- Class methods for public interface

**Usage Across Application:**
- Participant flow: Check task requirement fulfillment via `execute_condition`
- Task creation: Validate condition-model combinations via `validate_condition_exists`
- Form population: Provide select options via `model_condition_select_values`
- Progress tracking: Calculate completion percentages from `execute_condition` results

---

## Implementation Notes

### Security Considerations
- Temporary tokens must be deleted after single use
- QR codes should use UUID to prevent enumeration attacks
- Validate reward availability before allowing draws
- Enforce mission session status checks on all participant endpoints
- Validate reward validity period at draw time

### Performance Optimization
- Index participant_reward lookups by UUID
- Add composite index on (ticket_id/visitor_id, task_group) for claim status checks
- Cache `model_condition_select_values` response as it's static
- Consider indexing mission_session.status for published session queries
