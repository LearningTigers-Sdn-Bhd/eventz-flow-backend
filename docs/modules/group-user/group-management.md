# Group Management

## Model Snapshot

`groups` table

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint | primary key |
| `name` | string | required, indexed |
| `description` | text | optional |
| `created_at` / `updated_at` | timestamps | standard Rails timestamps |

### Associations

- `has_many :group_members` - Users (organizers/members) in the group
- `has_many :users, through: :group_members` - Direct access to member users
- `has_one :group_affiliate` - Vendor assignment (one per group)
- `has_one :vendor, through: :group_affiliate` - Direct access to assigned vendor

---

## List Groups

`GET /v1/groups`

Returns groups visible to the current user based on their role.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Sees all groups
- **Organizer/Member:** Sees groups they belong to via `group_members`
- **Vendor:** Sees groups they're assigned to via `group_affiliates`

**Success (200):**

```json
[
  {
    "id": 1,
    "name": "Mall A Group",
    "description": "Group for managing vendors in Mall A",
    "created_at": "2025-11-11T03:20:00Z",
    "updated_at": "2025-11-11T03:20:00Z"
  },
  {
    "id": 2,
    "name": "Mall B Group",
    "description": "Group for managing vendors in Mall B",
    "created_at": "2025-11-11T03:25:00Z",
    "updated_at": "2025-11-11T03:25:00Z"
  }
]
```

**Errors:**
- `401 Unauthorized` – missing or invalid token

---

## Show Group

`GET /v1/groups/:id`

Returns detailed information about a specific group including members.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Can view any group
- **Organizer/Member:** Can view groups they belong to
- **Vendor:** Can view groups they're assigned to

**Success (200):**

```json
{
  "id": 1,
  "name": "Mall A Group",
  "description": "Group for managing vendors in Mall A",
  "created_at": "2025-11-11T03:20:00Z",
  "updated_at": "2025-11-11T03:20:00Z",
  "members": [
    {
      "id": 1,
      "user_id": 5,
      "user": {
        "id": 5,
        "email": "organizer@example.com",
        "full_name": "John Organizer",
        "role": "organizer"
      },
      "has_manager_access": true
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
      "has_manager_access": false
    }
  ],
  "vendor": {
    "id": 7,
    "email": "vendor@example.com",
    "full_name": "Vendor Corp"
  }
}
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user not authorized to view this group
- `404 Not Found` – group doesn't exist

---

## Create Group

`POST /v1/groups`

Creates a new group. Only org_owner can create groups.

**Auth:** Bearer token (org_owner required)

**Body:**

```json
{
  "group": {
    "name": "Mall A Group",
    "description": "Group for managing vendors in Mall A",
    "manager_id": 5
  }
}
```

**Parameters:**
- `name` (required): Group name
- `description` (optional): Group description
- `manager_id` (optional): User ID to assign as the first group manager with `has_manager_access: true`

**Success (201):**

```json
{
  "id": 1,
  "name": "Mall A Group",
  "description": "Group for managing vendors in Mall A",
  "created_at": "2025-11-11T03:20:00Z",
  "updated_at": "2025-11-11T03:20:00Z"
}
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner
- `422 Unprocessable Content` – validation errors (e.g., missing name)

---

## Update Group

`PATCH /v1/groups/:id`

Updates group details (name, description). Only org_owner and group managers can update.

**Auth:** Bearer token (required)

**Authorization:**
- **org_owner:** Can update any group
- **Group Manager:** Can update groups where they have `has_manager_access: true`

**Body:**

```json
{
  "group": {
    "name": "Updated Group Name",
    "description": "Updated description"
  }
}
```

**Success (200):**

```json
{
  "id": 1,
  "name": "Updated Group Name",
  "description": "Updated description",
  "created_at": "2025-11-11T03:20:00Z",
  "updated_at": "2025-11-11T03:30:00Z"
}
```

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner or group manager
- `404 Not Found` – group doesn't exist
- `422 Unprocessable Content` – validation errors

---

## Delete Group

`DELETE /v1/groups/:id`

Deletes a group. Only org_owner can delete groups.

**Auth:** Bearer token (org_owner required)

**Success (204):** No content

**Errors:**
- `401 Unauthorized` – missing or invalid token
- `403 Forbidden` – user is not org_owner
- `404 Not Found` – group doesn't exist

---

## Related Data

- **GroupMember:** Stores user-group relationships with manager access flags
- **GroupAffiliate:** Stores vendor-group assignments (one vendor per group)
- **User:** Users with roles `organizer` or `member` can be added as group members
