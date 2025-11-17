# Group Members Management

## Model Snapshot

`group_members` table

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint | primary key |
| `group_id` | bigint | required, FK to `groups` |
| `user_id` | bigint | required, FK to `users` |
| `has_manager_access` | boolean | default: false, allows user to manage group |
| `created_at` / `updated_at` | timestamps | standard Rails timestamps |

**Constraints:**
- Unique index on `[group_id, user_id]` (one membership per user per group)
- User cannot be `org_owner`
- User must have role `organizer` or `member` (vendors excluded)

---

## List Group Members

`GET /v1/groups/:group_id/members`

Returns all members of a specific group.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Can view members of any group
- **Group Manager:** Can view members of groups they manage

**Success (200):**

```json
[
  {
    "id": 1,
    "user_id": 5,
    "user": {
      "id": 5,
      "email": "organizer@example.com",
      "full_name": "John Organizer",
      "role": "organizer"
    },
    "has_manager_access": true,
    "created_at": "2025-11-11T03:20:00Z",
    "updated_at": "2025-11-11T03:20:00Z"
  },
  {
    "id": 2,
    "user_id": 6,
    "user": {
      "id": 6,
      "email": "member@example.com",
      "full_name": "Jane Member",
      "role": "member"
    },
    "has_manager_access": false,
    "created_at": "2025-11-11T03:21:00Z",
    "updated_at": "2025-11-11T03:21:00Z"
  }
]
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner or group manager
- `404 Not Found` – group doesn't exist

---

## Add Member to Group

`POST /v1/groups/:group_id/members`

Adds a user to a group as a member or manager.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Can add members to any group
- **Group Manager:** Can add members to groups they manage

**Body:**

```json
{
  "group_member": {
    "user_id": 6,
    "has_manager_access": false
  }
}
```

**Parameters:**
- `user_id` (required): User ID to add to the group
- `has_manager_access` (optional, default: false): Set to `true` to grant manager access

**Validation Rules:**
- User cannot be `org_owner`
- User must have role `organizer` or `member`
- User cannot already be a member of the group

**Success (201):**

```json
{
  "id": 2,
  "user_id": 6,
  "user": {
    "id": 6,
    "email": "member@example.com",
    "full_name": "Jane Member",
    "role": "member"
  },
  "has_manager_access": false,
  "created_at": "2025-11-11T03:21:00Z",
  "updated_at": "2025-11-11T03:21:00Z"
}
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner or group manager
- `404 Not Found` – group or user doesn't exist
- `422 Unprocessable Content` – validation errors (e.g., user is org_owner, duplicate membership)

---

## Update Group Member

`PATCH /v1/groups/:group_id/members/:id`

Updates a group member, primarily to toggle manager access.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Can update members of any group
- **Group Manager:** Can update members of groups they manage

**Body:**

```json
{
  "group_member": {
    "has_manager_access": true
  }
}
```

**Parameters:**
- `has_manager_access` (optional): Toggle manager access for the member

**Success (200):**

```json
{
  "id": 2,
  "user_id": 6,
  "user": {
    "id": 6,
    "email": "member@example.com",
    "full_name": "Jane Member",
    "role": "member"
  },
  "has_manager_access": true,
  "created_at": "2025-11-11T03:21:00Z",
  "updated_at": "2025-11-11T03:30:00Z"
}
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner or group manager
- `404 Not Found` – group or member doesn't exist
- `422 Unprocessable Content` – validation errors

---

## Remove Member from Group

`DELETE /v1/groups/:group_id/members/:id`

Removes a user from a group.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Can remove members from any group
- **Group Manager:** Can remove members from groups they manage

**Success (204):** No content

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner or group manager
- `404 Not Found` – group or member doesn't exist

---

## Manager Access

The `has_manager_access` flag grants users the ability to:
- Update group details (name, description)
- Add/remove group members
- Toggle manager access for other members

Multiple users can have manager access to the same group. This allows for collaborative group management while maintaining org_owner's system-wide control.

---

## Related Data

- **Group:** Parent group that contains the members
- **User:** Users with roles `organizer` or `member` can be group members
- **GroupAffiliate:** Separate from group members, used for vendor assignments
