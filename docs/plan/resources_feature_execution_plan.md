# Resources Feature: Technical Execution Plan

This document outlines the technical steps required to implement the Resources and Content Management System feature. The plan is divided into phases, starting with the backend database and model setup, followed by API endpoint implementation, and concluding with authorization and testing.

---

### Phase 1: Database and Models

- [x] **Create Database Migration:**
  - [x] Generate a single migration file to create the `resource_write_permissions`, `resource_topics`, `resource_categories`, `resource_media_types`, `resources`, and `resource_leads` tables.

- [x] **Define ActiveRecord Models:**
  - [x] Create `ResourceWritePermission` model (`app/models/resource_write_permission.rb`).
  - [x] Create `ResourceTopic` model (`app/models/resource_topic.rb`).
  - [x] Create `ResourceCategory` model (`app/models/resource_category.rb`).
  - [x] Create `ResourceMediaType` model (`app/models/resource_media_type.rb`).
  - [x] Create `Resource` model (`app/models/resource.rb`).
  - [x] Create `ResourceLead` model (`app/models/resource_lead.rb`).

- [x] **Implement Model Logic & Associations:**
  - [x] Add associations (`belongs_to`, `has_many`, etc.) to all new models.
  - [x] Add validations (e.g., presence, uniqueness) to all new models.
  - [x] Implement `status` enums for `ResourceWritePermission` and `Resource` models.
  - [x] Implement soft-delete functionality for models with a `deleted_at` column.
  - [x] Add a `slug` generation mechanism to the `Resource` model (e.g., using a callback or `friendly_id` gem).
  - [x] Ensure the `article` field in the `Resource` model can handle rich-text (HTML) content.

- [x] **Create Seed Data:**
  - [x] In `db/seeds.rb`, add logic to populate `ResourceTopic` with: "Event Management", "AI at work", "Business Matching", "Project Planning".
  - [x] In `db/seeds.rb`, add logic to populate `ResourceCategory` with: "Corporate", "Wedding", "Exhibition", "Celebration".
  - [x] In `db/seeds.rb`, add logic to populate `ResourceMediaType` with: "Audiobook", "eBook", "Article", "Report", "Webinar", "Video".

---

### Phase 2: Controller Creation and Routing

- [x] **Create Resource Controllers:**
  - [x] `app/controllers/v1/resources_permissions_controller.rb`
  - [x] `app/controllers/v1/resources_topics_controller.rb`
  - [x] `app/controllers/v1/resources_categories_controller.rb`
  - [x] `app/controllers/v1/resources_media_types_controller.rb`
  - [x] `app/controllers/v1/resources_controller.rb`
  - [x] `app/controllers/v1/resources_leads_controller.rb`

- [x] **Define Routes (`config/routes.rb`):**
  - [x] `resources :resources_permissions, path: 'resources/permissions', except: [:new]`
  - [x] `resources :resources_topics, path: 'resources/topics', except: [:new]` with `force_destroy` and `restore` members.
  - [x] `resources :resources_categories, path: 'resources/categories', except: [:new]` with `force_destroy` and `restore` members.
  - [x] `resources :resources_media_types, path: 'resources/media_types', except: [:new]` with `force_destroy` and `restore` members.
  - [x] `resources :resources, path: 'resources', except: [:new]` with `force_destroy`, `restore`, and `approval` members.
  - [x] `resources :resources_leads, path: 'resources/leads', only: [:index, :show, :create, :store]` with `metrics` collection.

- [x] **Implement Controller Actions & Policy Integration:**
  - [x] **Permissions:** Implement `index, show, create, store, edit, update, destroy`. Apply policy checks in each action.
  - [x] **Topics:** Implement `index, show, create, store, edit, update, destroy, force_destroy, restore`. Apply policy checks.
  - [x] **Categories:** Implement `index, show, create, store, edit, update, destroy, force_destroy, restore`. Apply policy checks.
  - [x] **Media Types:** Implement `index, show, create, store, edit, update, destroy, force_destroy, restore`. Apply policy checks.
  - [x] **Resources:** Implement `index, show, create, store, edit, update, destroy, force_destroy, restore, approval`. Apply policy checks.
  - [x] **Leads:** Implement `index, show, create, store, metrics`. Apply policy checks.

---

### Phase 3: Authorization Logic (Pundit Policies)

- [x] **Create and Define Pundit Policies:**
  - [x] **ResourcePermissionPolicy:**
    - `index, show, create, store, edit, update, destroy` -> Admin only.
  - [x] **ResourceTopicPolicy:**
    - `index, show` -> All users.
    - `create, store, edit, update, destroy, force_destroy, restore` -> Admin only.
  - [x] **ResourceCategoryPolicy:**
    - `index, show` -> All users.
    - `create, store` -> Admin or Writer.
    - `edit, update, destroy, force_destroy, restore` -> Admin only.
  - [x] **ResourceMediaTypePolicy:**
    - `index, show` -> All users.
    - `create, store, edit, update, destroy, force_destroy, restore` -> Admin only.
  - [x] **ResourcePolicy:**
    - `index, show` -> All users.
    - `create, store, edit, update, destroy, restore` -> Admin or Writer (scoped to own resources for writers).
    - `force_destroy, approval` -> Admin only.
  - [x] **ResourceLeadPolicy:**
    - `index, show, metrics` -> Admin only.
    - `create, store` -> Visitor (public action).

---

### Phase 4: Testing (RSpec)

- [x] **Write Model Specs:**
  - [x] Specs for all new models, covering validations, associations, and custom methods.

- [x] **Write Request Specs:**
  - [x] Test every new endpoint (e.g., `POST /v1/resources/topics`).
  - [x] Create tests for each user role (Admin, Writer, Visitor) to verify policy enforcement (2xx for authorized, 403 for unauthorized).
  - [x] Test soft and hard delete actions (`destroy`, `force_destroy`, `restore`).
  - [x] Test resource approval flow.
  - [x] Test lead creation and metrics endpoints.

- [x] **Write Policy Specs:**
  - [x] Test permissions for each role in all Pundit policies to ensure correct access control logic.