# Event Roles Documentation

## Overview

EventzFlow uses a two-tier role system for access control:
- **Global Roles**: System-wide permissions stored in the `users` table
- **Event-Specific Roles**: Per-event permissions stored in the `event_assignments` table

This document describes all available roles and their permissions.

---

## Table of Contents

1. [Global Roles](#global-roles)
2. [Event-Specific Roles](#event-specific-roles)
3. [Permission Matrix](#permission-matrix)
4. [API Usage](#api-usage)
5. [Role Assignment](#role-assignment)

---

## Global Roles

Global roles are assigned to users and apply system-wide. These roles are stored in the `users.role` column as integers.

### org_owner (Value: 0)
**Highest authority in the system.**

**Permissions:**
- Full system access
- View/manage all users
- Update any user's global role
- Delete users
- Create/manage all events
- View all events (regardless of visibility/publish status)
- Manage event staff assignments
- View/manage all tickets
- Unscan tickets
- Manage global ticket types
- Access all analytics
- Create/manage API keys

### manager (Value: 1)
**Organization manager with system-wide event management.**

**Permissions:**
- View all users
- Create/manage events
- View assigned events (events they are assigned to via `event_assignments`)
- Update/delete assigned events
- View/manage tickets for assigned events
- Check-in tickets for assigned events
- Access global and event analytics
- Cannot update user roles
- Cannot delete users
- Cannot unscan tickets
- Cannot manage API keys

### member (Value: 2 - Default)
**Standard user/participant with limited access.**

**Permissions:**
- View own profile
- View published and visible events
- Purchase tickets (through participation)
- Cannot create/manage events
- Cannot view tickets (except own)
- Cannot access analytics
- Cannot manage users

---

## Event-Specific Roles

Event-specific roles are assigned per event and stored in the `event_assignments` table. A user can have different roles for different events.

### event_admin
**Event organizer with full event management.**

**Permissions:**
- View assigned events (even if not published/visible)
- Update/delete assigned events
- Create/manage tickets for assigned events
- View/update/delete tickets for assigned events
- Check-in tickets for assigned events
- Manage ticket types for assigned events
- Manage event locations for assigned events
- View event analytics for assigned events
- Import/export tickets for assigned events
- Cannot create events (must be `org_owner` or `manager`)
- Cannot unscan tickets
- Cannot manage global ticket types
- Cannot view/manage other users' global roles

### event_team_member
**Committee member with limited event management.**

**Permissions:**
- View assigned events (even if not published/visible)
- Update assigned events (cannot delete)
- View tickets for assigned events
- Update tickets for assigned events
- Check-in tickets for assigned events
- View event locations for assigned events
- View event analytics for assigned events
- Export tickets for assigned events
- Cannot create events
- Cannot delete events
- Cannot create/delete tickets
- Cannot delete tickets
- Cannot manage ticket types
- Cannot manage event locations
- Cannot import tickets
- Cannot unscan tickets

### event_vendor
**Merchant/exhibitor/panel with read-only event access.**

**Permissions:**
- View assigned events (even if not published/visible)
- View event locations (read-only)
- See assigned events in event index
- Cannot view tickets
- Cannot create/update/delete tickets
- Cannot update/delete events
- Cannot view analytics
- Cannot create events
- Cannot view event staff list
- Cannot manage event staff
- Cannot manage ticket types
- Cannot manage event locations

---

## Permission Matrix

| Action | org_owner | manager | member | event_admin | event_team_member | event_vendor |
|--------|-----------|---------|--------|-------------|-------------------|--------------|
| **User Management** |
| View all users | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Update user roles | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Delete users | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Event Management** |
| Create events | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View all events | ✅ | Assigned only | Published only | Assigned only | Assigned only | Assigned only |
| Update events | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ✅ (assigned) | ❌ |
| Delete events | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ❌ | ❌ |
| **Event Staff** |
| View event staff | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Assign event staff | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Tickets** |
| View tickets | ✅ (all) | ✅ (assigned) | Own only | ✅ (assigned) | ✅ (assigned) | ❌ |
| Create tickets | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ❌ | ❌ |
| Update tickets | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ✅ (assigned) | ❌ |
| Delete tickets | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ❌ | ❌ |
| Check-in tickets | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ✅ (assigned) | ❌ |
| Unscan tickets | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Ticket Types** |
| Manage global types | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Manage event types | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ❌ | ❌ |
| **Event Locations** |
| View locations | ✅ (all) | ✅ (assigned) | ✅ (published) | ✅ (assigned) | ✅ (assigned) | ✅ (assigned) |
| Manage locations | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ❌ | ❌ |
| **Analytics** |
| Global analytics | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Event analytics | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ✅ (assigned) | ❌ |
| **Imports/Exports** |
| Import tickets | ✅ | ✅ | ❌ | ✅ (assigned) | ❌ | ❌ |
| Export tickets | ✅ (all) | ✅ (assigned) | ❌ | ✅ (assigned) | ✅ (assigned) | ❌ |
| **API Keys** |
| Manage API keys | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Legend:**
- ✅ = Allowed
- ❌ = Not allowed
- "Assigned" = Only for events the user is assigned to via `event_assignments`
- "Published" = Only for events that are published and visible

---

## API Usage

### Assigning Event-Specific Roles

Event-specific roles are assigned via the Event Staff Management endpoint.

#### POST `/v1/events/:event_id/staff`

Assign a user to an event with a specific role.

**Request:**
```json
{
  "staff_assignment": {
    "user_id": "123",
    "role": "event_vendor"
  }
}
```

**Available Roles:**
- `event_admin`
- `event_team_member`
- `event_vendor`

**Authorization:**
- Only `org_owner` can assign/remove event staff roles

**Response (201 Created):**
```json
{
  "id": 1,
  "event_id": 1,
  "user_id": "123",
  "role": "event_vendor"
}
```

#### GET `/v1/events/:event_id/staff`

View all staff assignments for an event.

**Authorization:**
- `org_owner`
- `manager`
- `event_admin` (for their assigned events)
- `event_team_member` (for their assigned events)

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "event_id": 1,
    "user_id": "123",
    "role": "event_admin",
    "user": {
      "id": "123",
      "email": "admin@example.com",
      "full_name": "John Doe",
      "phone": "+1234567890",
      "role": "manager",
      "status": "active"
    }
  },
  {
    "id": 2,
    "event_id": 1,
    "user_id": "456",
    "role": "event_vendor",
    "user": {
      "id": "456",
      "email": "vendor@example.com",
      "full_name": "Jane Smith",
      "phone": "+0987654321",
      "role": "member",
      "status": "active"
    }
  }
]
```

#### DELETE `/v1/events/:event_id/staff/:user_id`

Remove a user's event assignment.

**Authorization:**
- Only `org_owner` can remove event staff assignments

**Response (204 No Content):**
No content returned.

### Viewing Events

Events are automatically filtered based on user roles and assignments.

#### GET `/v1/events`

Returns events based on user's role and assignments:
- `org_owner`: All events
- `manager`/`member`/event roles: Only assigned events (where `visibility = true`)

**Authorization:**
- All authenticated users

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "title": "Tech Conference 2024",
    "description": "Annual technology conference",
    "status": "published",
    "visibility": true,
    "start_date": "2024-06-01T09:00:00Z",
    "end_date": "2024-06-03T17:00:00Z",
    ...
  }
]
```

### Viewing Event Details

#### GET `/v1/events/:id`

View a specific event's details.

**Authorization:**
- Public events (published AND visible): All users
- Private events: `org_owner`, `manager`, or users with event assignments (`event_admin`, `event_team_member`, `event_vendor`)

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Tech Conference 2024",
  "description": "Annual technology conference",
  "status": "published",
  "visibility": true,
  "start_date": "2024-06-01T09:00:00Z",
  "end_date": "2024-06-03T17:00:00Z",
  ...
}
```

---

## Role Assignment

### Creating Events with Event Admin

When creating an event, you can optionally assign an event admin:

#### POST `/v1/events`

**Request:**
```json
{
  "event": {
    "title": "Tech Conference 2024",
    "description": "Annual technology conference",
    "start_date": "2024-06-01T09:00:00Z",
    "end_date": "2024-06-03T17:00:00Z",
    "event_admin_id": 123
  }
}
```

If `event_admin_id` is not provided, the current user (who must be `org_owner` or `manager`) is automatically assigned as `event_admin`.

### Updating Global User Roles

Only `org_owner` can update global user roles.

#### PUT `/v1/users/:id/role`

**Request:**
```json
{
  "user": {
    "role": "manager"
  }
}
```

**Available Global Roles:**
- `org_owner`
- `manager`
- `member`

**Authorization:**
- Only `org_owner`

**Response (200 OK):**
```json
{
  "user": {
    "id": "123",
    "email": "user@example.com",
    "role": "manager",
    "full_name": "John Doe"
  }
}
```

---

## Best Practices

1. **Role Hierarchy**: Use the least privileged role that meets the user's needs
2. **Event Assignments**: Assign event-specific roles only when users need access to specific events
3. **Vendor Access**: Use `event_vendor` for merchants, exhibitors, and panel participants who need read-only event access
4. **Staff Management**: Only `org_owner` should manage event staff assignments to maintain security
5. **Event Visibility**: Use `visibility` flag to control which events appear in public listings while still allowing assigned users to access them

---

## Notes

- A user can have different event-specific roles for different events
- Event-specific roles are independent of global roles
- `event_vendor` role is read-only and does not grant management permissions
- `event_staff?` helper method only returns `true` for `event_admin` and `event_team_member`, not `event_vendor`
- Event assignments are unique per user per event (one role per user per event)

---

## Related Documentation

- [Ticket Excel Import/Export](./TICKET_EXCEL_IMPORT_EXPORT.md)
- API Documentation (Swagger): `/api-docs`
