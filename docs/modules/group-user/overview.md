# Group-User Module Overview

The group-user module enables organizational grouping of users (organizers and members) and vendor assignment. Groups allow vendors to manage multiple organizational units (e.g., "Mall A" and "Mall B") while maintaining clear ownership and access control.

## Feature Map

| Area | Summary | Docs |
| --- | --- | --- |
| Group Management | CRUD operations for groups (org_owner only for create/delete) | [`group-management.md`](group-management.md) |
| Group Members | Add, update, remove members; toggle manager access | [`group-members.md`](group-members.md) |
| Group Affiliates | Assign vendors to groups (one vendor per group) | [`group-affiliates.md`](group-affiliates.md) |

## Architecture Highlights

- **Groups:** `Group` model stores name and description. Groups are created by org_owner and can be updated by org_owner or group managers.
- **Group Members:** `GroupMember` join table connects users (organizers/members only) to groups with `has_manager_access` flag. Multiple users can have manager access per group.
- **Group Affiliates:** `GroupAffiliate` assigns one vendor per group. Vendors can be assigned to multiple groups (many-to-many relationship).
- **Authorization:**
  - **org_owner:** Full control (create, delete groups, assign vendors)
  - **Group Managers:** Can update group details and manage members
  - **Members:** Can view groups they belong to
  - **Vendors:** Can view groups they're assigned to via affiliates
- **Visibility:** Groups are filtered by role - org_owner sees all, others see only their groups.

## Use Cases

1. **Vendor Multi-Location Management:** A vendor can manage multiple groups (e.g., "Mall A" and "Mall B") to organize their operations.
2. **Organizational Structure:** Organizers can be assigned to groups to handle internal operations while org_owner maintains system-wide control.
3. **Member Organization:** Members can be added to groups for better organization and access control.

## Key Business Rules

1. Only org_owner can create and delete groups
2. org_owner and group managers (has_manager_access=true) can update group details
3. org_owner and group managers can manage group members
4. Only org_owner can assign/remove vendors from groups
5. org_owner cannot be added as a group member
6. Vendors cannot be added as group members (only via group_affiliates)
7. One vendor per group, but vendors can belong to multiple groups

Use the linked documents for endpoint details, request/response payloads, and authorization rules.
