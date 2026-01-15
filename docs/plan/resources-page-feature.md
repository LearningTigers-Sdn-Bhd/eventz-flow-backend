# Resources Page Feature

## Overview

This feature enables a content management system (CMS) within the platform, allowing designated users to author and publish diverse resources such as articles, downloadable media, and webinars. The primary objective is to build topical authority in event management, thereby improving the website's SEO and driving organic traffic.

## User Roles & Capabilities

### Author (User)

- Can access the resource authoring dashboard once granted permission.
- Can create, edit, and submit resources (articles, media, etc.) for publication.

### Admin

- Can grant or revoke writing permissions for users.
- Can designate specific authors as "Official Team Members."
- Has full management capabilities over topics, categories, and published resources.

### Visitor / Lead

- **General Visitor**: Can view and access public resources.
- **Lead**: Can access "Gated" content (Lead Magnets like eBooks or Webinars) by submitting a lead generation form. Account registration is not required.

## Business Rules

**Access Control & Content Management:**

- **ResourceWritePermission** (Admin: Full Control)
  - Admins can grant writing permissions to users, enabling them to become content authors
  - Admins can specify and update the scope of content each author is authorized to create
  - Admins can designate authors as "Official Team Members" for branded content
  - Admins can revoke author access and permissions at any time

- **ResourceTopic** (Admin: Full Control)
  - Admins maintain a curated list of content topics (e.g., "AI Content", "Event Technology")
  - Authors select from available topics when creating resources to ensure content alignment
  - Topics help organize resources by specific subject matter for better discoverability

- **ResourceCategory** (Admin: Full Control, Author: Create & Read)
  - Admins manage high-level content categories for organizational structure
  - Authors can propose new categories to accommodate diverse content needs
  - Only admins can modify or remove categories to maintain taxonomy consistency

- **ResourceMediaType** (Admin: Full Control)
  - Admins define available content formats (e.g., "Article", "E-Book", "Webinar", "Infographic")
  - Selected media type determines the authoring interface and content structure
  - Ensures consistent formatting and user experience across different resource types

- **Resources** (Admin: Full Control, Author: Full Control with Restrictions)
  - Admins have unrestricted access to create, edit, publish, and delete all resources
  - Official team members can publish content under the organization's brand
  - Individual authors can manage their own resource posts but cannot publish as official content
  - All resources follow a workflow: Draft → In Review → Published
  - Both gated and public content can be created to support different marketing strategies

- **ResourceLeads** (Visitor: Submit Only, Admin: Read & Analyze)
  - Visitors submit contact information via lead capture forms to access gated content
  - No account registration required for lead generation
  - Admins can view, export, and analyze lead data for marketing and sales purposes
  - Lead information includes contact details, company data, and resource access history

## Database Schema

### ResourceWritePermission
Tracks which users are authorized to create content and their status within the editorial team.

**Fields:**
- `id` (primary key)
- `user_id` (foreign key, unique) - Links to the User table; one permission entry per user.
- `is_official` (boolean, default: false) - `true` indicates the user is an official team member/writer.
- `status` (integer, default: 0) - `0`: Base, `1`: Partnership.
- Timestamps

---

### ResourceTopic
Defines the specific subjects or themes that resources can cover (e.g., "Event Marketing", "Logistics").

**Fields:**
- `id` (primary key)
- `name` (string)
- `description` (text, nullable)
- `logo` (string, nullable) - Icon or image representing the topic.
- `deleted_at` (timestamp, nullable) - Soft delete.
- Timestamps

---

### ResourceCategory
Broad classification for resources, helping organize content at a high level.

**Fields:**
- `id` (primary key)
- `name` (string)
- `description` (text, nullable)
- `deleted_at` (timestamp, nullable) - Soft delete.
- Timestamps

---

### ResourceMediaType
Defines the format of the resource (e.g., "Article", "E-Book", "Webinar").

**Fields:**
- `id` (primary key)
- `name` (string)
- `description` (text, nullable)
- `deleted_at` (timestamp, nullable) - Soft delete.
- Timestamps

---

### Resources
The main table storing the content of the resources.

**Fields:**
- `id` (primary key)
- `title` (string)
- `article` (text) - Main content body.
- `slug` (string, unique) - URL-friendly identifier for SEO.
- `meta_description` (string) - Summary for search engine results.
- `user_id` (foreign key) - The author of the resource.
- `topic_id` (foreign key) - The specific topic discussed.
- `category_id` (foreign key) - The broad category of the resource.
- `media_type_id` (foreign key) - The format of the resource.
- `status` (integer, default: 0) - `0`: Draft, `1`: In Review, `2`: Published.
- `published_at` (timestamp, nullable)
- `deleted_at` (timestamp, nullable) - Soft delete.
- `view_counts` (integer, default: 0)
- `is_gated` (boolean, default: false) - If `true`, requires form submission to access.
- `is_official` (boolean, default: false) - If `true`, when the author is `admin` or `author.is_official`, who is decided to post the resource as official or not.
- Timestamps

---

### ResourceLeads
Captures information from visitors who access gated resources (Lead Magnets).

**Fields:**
- `id` (primary key)
- `email` (string)
- `name` (string)
- `phone` (string)
- `company_name` (string)
- `state` (string)
- `country` (string)
- `job_title` (string)
- `ip_address` (string, nullable)
- `accessed_at` (timestamp, nullable)
