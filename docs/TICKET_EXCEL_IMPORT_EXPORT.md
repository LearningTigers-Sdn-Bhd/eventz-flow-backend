# Ticket Excel Import/Export Documentation

## Overview

The EventzFlow API provides Excel import/export functionality for ticket management. This allows administrators to:
- **Export** ticket data to Excel files with QR codes
- **Import** ticket data from Excel files to create bulk tickets
- **Track** export history with downloadable files

---

## Table of Contents

1. [Authentication](#authentication)
2. [Import Endpoint](#import-endpoint)
3. [Export Endpoints](#export-endpoints)
4. [Excel File Format](#excel-file-format)
5. [Error Handling](#error-handling)
6. [Examples](#examples)

---

## Authentication

All endpoints require Bearer token authentication:

```
Authorization: Bearer YOUR_JWT_TOKEN
```

**Requirements:**
- Valid JWT token
- Verified email address
- Appropriate event access permissions (via Pundit authorization)

---

## Import Endpoint

### POST `/v1/imports/tickets`

Import tickets from an Excel file.

#### Request

**Content-Type:** `multipart/form-data`

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | File | Yes | Excel file (.xlsx) containing ticket data |
| `dry_run` | Boolean (query) | No | If true, validate and report without writing changes |
| `full` | Boolean (query) | No | If true, use full import mode with additional validation and processing |

**Headers:**
```
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: multipart/form-data
```

#### Response

**Success (200 OK):**
```json
{
  "success": true,
  "message": "Import completed: 5 total processed (5 created, 1 updated, 2 skipped)",
  "data": {
    "total": 8,
    "created": {
      "count": 5,
      "data": [
        {
          "model": "ticket",
          "id": "123",
          "attendee_name": "John Doe",
          "attendee_email": "john@example.com"
        }
      ]
    },
    "updated": {
      "count": 1,
      "data": [
        {
          "model": "ticket",
          "id": "124",
          "attendee_name": "Jane Smith",
          "attendee_email": "jane@example.com"
        }
      ]
    },
    "skipped": {
      "count": 2,
      "data": [
        {
          "model": "ticket",
          "id": "125",
          "attendee_name": "Bob Johnson",
          "attendee_email": "bob@example.com"
        }
      ]
    },
    "duplicates_in_file": {
      "count": 1,
      "data": [
        {
          "model": "ticket",
          "id": "126",
          "attendee_name": "Duplicate User",
          "attendee_email": "duplicate@example.com"
        }
      ]
    },
    "errors": {
      "count": 0,
      "data": []
    }
  }
}
```

**Error (422 Unprocessable Entity):**
```json
{
  "success": false,
  "message": "Import failed",
  "errors": ["Row 3: Event not found", "Row 5: Invalid email"]
}
```

#### Behavior

1. **Event Lookup/Creation:**
   - Finds event by `Event Title` column
   - If not found, creates a new event with:
     - Status: `draft`
     - Start Date: 10 days from now
     - End Date: 20 days from now
     - Visibility: `true`

2. **Ticket Type:**
   - Uses or creates "General Admission" ticket type ($0)

3. **Duplicate Handling:**
   - In-file: collapse only when names match within the same Event + Ticket Type (case-insensitive, spaces collapsed). If names differ, keep both rows even if email/phone are identical.
   - Against DB: if name matches within the same Event + Ticket Type, update only if the new row is more complete (merge custom fields, only upgrade payment status, never uncheck). If email/phone matches but name differs, create a new ticket.

4. **Dynamic Fields:**
   - Additional columns beyond standard fields become custom fields
   - Updates event's `labels_data` schema automatically

---

## Export Endpoints

### 1. Create Export

#### POST `/v1/tickets/exports?event_id={event_id}`

Generate a new Excel export for an event.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `event_id` | Integer | Yes | Event ID to export tickets for |

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Export created successfully",
  "data": {
    "id": 123,
    "type": "ticket-list",
    "created_at": "2025-11-03T12:34:56.789Z",
    "event_id": 45
  }
}
```

---

### 2. List Exports

#### GET `/v1/tickets/exports?event_id={event_id}`

Retrieve all export history for an event.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `event_id` | Integer | Yes | Event ID to list exports for |

**Response (200 OK):**
```json
[
  {
    "id": 123,
    "type": "ticket-list",
    "created_at": "2025-11-03T12:34:56.789Z",
    "updated_at": "2025-11-03T12:34:56.789Z",
    "event": {
      "id": 45,
      "title": "Tech Conference 2025"
    }
  },
  {
    "id": 122,
    "type": "ticket-list",
    "created_at": "2025-11-02T10:20:30.456Z",
    "updated_at": "2025-11-02T10:20:30.456Z",
    "event": {
      "id": 45,
      "title": "Tech Conference 2025"
    }
  }
]
```

---

### 3. Download Export

#### GET `/v1/tickets/exports/{id}`

Download a specific exported Excel file.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | Integer | Yes | Export log ID |

**Response:**
- **Content-Type:** `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- **File Download:** Binary Excel file

---

## Excel File Format

### Standard Columns (Required)

| Column Name | Type | Required | Description | Example |
|-------------|------|----------|-------------|---------|
| **Attendee Name** | String | Yes | Full name of attendee | "John Doe" |
| **Attendee Email** | String | No | Email address (unique per event if present) | "john@example.com" |
| **Attendee Phone** | String | No | Phone number | "+1234567890" |
| **Event Title** | String | Yes | Name of the event | "Tech Conference" |
| **Ticket Type** | String | No | Ticket type name; defaults to "General Admission" if blank | "VIP" |
| **Public ID** | String | No | UUID (auto-generated if empty) | "abc-123-def" |
| **QR Code** | Formula | No | Generated QR code image | (Excel formula) |
| **Payment Status** | Enum | No | Ticket payment state (`pending`, `paid`, `failed`, `refunded`) | "paid" |
| **Checked In** | Boolean | No | Check-in status | "true" or "false" |

### Dynamic Custom Fields

Any additional columns after "Checked In" are treated as custom fields:

| Example Columns | Description |
|-----------------|-------------|
| **Role** | Custom field: Attendee role |
| **Company** | Custom field: Company name |
| **Dietary Restrictions** | Custom field: Food preferences |

**Example Row:**
```
| Attendee Name | Attendee Email | ... | Ticket Type | Payment Status | Checked In | Role | Company |
|---------------|----------------|-----|-------------|----------------|------------|------|---------|
| John Doe      | john@test.com  | ... | VIP         | paid           | false      | VIP  | Acme Co |
```

### QR Code Formula

The QR Code column uses an Excel `IMAGE` formula:

```excel
=IMAGE("https://quickchart.io/qr?text=" & ENCODEURL(E2))
```

Where `E2` references the **Public ID** column.

### Labels Data Format

**In Event (`labels_data` JSONB):**
```json
{
  "role": "Role",
  "company": "Company",
  "dietary": "Dietary Restrictions"
}
```

**In Ticket (`custom_fields_data` JSONB):**
```json
{
  "role": "VIP",
  "company": "Acme Corporation",
  "dietary": "Vegetarian"
}
```

---

## Error Handling

### Common Error Responses

#### 401 Unauthorized
```json
{
  "success": false,
  "message": "Unauthorized",
  "errors": []
}
```

**Causes:**
- Missing or invalid JWT token
- Expired token

---

#### 403 Forbidden
```json
{
  "success": false,
  "message": "Not authorized to export tickets for this event",
  "errors": []
}
```

**Causes:**
- User doesn't have access to the event
- Email not verified

---

#### 404 Not Found
```json
{
  "error": "Event not found"
}
```

**Causes:**
- Invalid event ID
- Export log not found
- Export file deleted from server

---

#### 422 Unprocessable Entity
```json
{
  "success": false,
  "message": "Import failed",
  "errors": ["Row 5: Attendee email can't be blank"]
}
```

**Causes:**
- Invalid file format
- Missing required fields
- Validation errors in data

---

## Examples

### Example 1: Import Tickets

**cURL:**
```bash
curl -X POST "https://api.eventzflow.com/v1/imports/tickets" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@tickets.xlsx"
```

**With query parameters:**
```bash
curl -X POST "https://api.eventzflow.com/v1/imports/tickets?dry_run=true&full=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@tickets.xlsx"
```

**Response:**
```json
{
  "success": true,
  "message": "Import completed: 10 total processed (10 created, 2 skipped)",
  "data": {
    "total": 12,
    "created": {
      "count": 10,
      "data": [
        {
          "model": "ticket",
          "id": "123",
          "attendee_name": "John Doe",
          "attendee_email": "john@example.com"
        }
      ]
    },
    "skipped": {
      "count": 2,
      "data": [
        {
          "model": "ticket",
          "id": "124",
          "attendee_name": "Jane Smith",
          "attendee_email": "jane@example.com"
        }
      ]
    },
    "errors": {
      "count": 0,
      "data": []
    }
  }
}
```

---

### Example 2: Create Export

**cURL:**
```bash
curl -X POST "https://api.eventzflow.com/v1/tickets/exports?event_id=45" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "success": true,
  "message": "Export created successfully",
  "data": {
    "id": 123,
    "type": "ticket-list",
    "created_at": "2025-11-03T12:34:56.789Z",
    "event_id": 45
  }
}
```

---

### Example 3: List Export History

**cURL:**
```bash
curl -X GET "https://api.eventzflow.com/v1/tickets/exports?event_id=45" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**
```json
[
  {
    "id": 123,
    "type": "ticket-list",
    "created_at": "2025-11-03T12:34:56.789Z",
    "event": {
      "id": 45,
      "title": "Tech Conference 2025"
    }
  }
]
```

---

### Example 4: Download Export File

**cURL:**
```bash
curl -X GET "https://api.eventzflow.com/v1/tickets/exports/123" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o export.xlsx
```

**Result:** Downloads `export.xlsx` file

---

## Sample Excel Template

### Minimal Template (Required Fields Only)

| Attendee Name | Attendee Email | Attendee Phone | Event Title | Ticket Type | Public ID | QR Code | Payment Status | Checked In |
|---------------|----------------|----------------|-------------|-------------|-----------|---------|----------------|------------|
| John Doe      |                | +1234567890    | My Event    |             |           |         |                | false      |
| Jane Smith    | jane@test.com  |                | My Event    | VIP         |           |         | paid           | false      |

### Extended Template (With Custom Fields)

| Attendee Name | Attendee Email | Attendee Phone | Event Title | Ticket Type | Public ID | QR Code | Payment Status | Checked In | Role     | Company      | T-Shirt Size |
|---------------|----------------|----------------|-------------|-------------|-----------|---------|----------------|------------|----------|--------------|--------------|
| John Doe      | john@test.com  | +1234567890    | My Event    | VIP         |           |         | paid           | false      | Speaker  | Acme Corp    | L            |
| Jane Smith    |                 | +0987654321    | My Event    |             |           |         | pending        | false      | Attendee | Beta Inc     | M            |

---

## Technical Details

### Storage

- Export files are stored in: `storage/exports/`
- File naming format: `tickets-{event_id}-{timestamp}.xlsx`
- Example: `tickets-45-20251103_123456.xlsx`

### Database Schema

**ExportLog Model:**
```ruby
class ExportLog < ApplicationRecord
  belongs_to :event

  # Columns:
  # - id (integer)
  # - type (string) - e.g., "ticket-list"
  # - sheet_path (string) - full path to Excel file
  # - event_id (integer) - foreign key
  # - created_at (datetime)
  # - updated_at (datetime)
end
```

### Service Object

The import/export logic is handled by:
```ruby
TicketExcelService.export(event_id)
TicketExcelService.import(file, dry_run: false, full: false)
```

---

## Best Practices

### For Imports

1. **Validate Data First:** Check your Excel file for required fields before importing
2. **Use Unique Emails:** Ensure each attendee has a unique email per event
3. **Consistent Event Titles:** Use exact event names to avoid creating duplicates
4. **Test Small Batches:** Import a few rows first to test the format

### For Exports

1. **Regular Backups:** Create exports periodically as backups
2. **Storage Management:** Old export files should be cleaned up periodically
3. **Access Control:** Only authorized users can access event exports

### For Custom Fields

1. **Consistent Naming:** Use the same custom field names across imports
2. **Descriptive Headers:** Make column headers clear and descriptive
3. **Schema Evolution:** New columns automatically update the event's labels schema

---

## Troubleshooting

### Import Issues

**Problem:** "Row X: Event not found"
- **Solution:** Ensure the Event Title exactly matches an existing event, or the system will create a new draft event

**Problem:** "Tickets skipped during import"
- **Solution:** This is normal - tickets with duplicate emails for the same event are automatically skipped

**Problem:** "Invalid file format"
- **Solution:** Ensure you're uploading a `.xlsx` file (not `.xls` or `.csv`)

### Export Issues

**Problem:** "Export file not found"
- **Solution:** The file may have been deleted from the server. Create a new export.

**Problem:** "Not authorized to view exports"
- **Solution:** Ensure you have proper permissions for the event

---

## API Versioning

Current API Version: **v1**

Base URL: `https://api.eventzflow.com/v1`

---

## Rate Limiting

- Import operations may take longer for large files (500+ rows)
- Export operations are asynchronous and generate files on-demand
- Consider implementing pagination for very large export lists

---

## Security Considerations

1. **Authentication Required:** All endpoints require valid JWT tokens
2. **Email Verification:** Users must have verified emails
3. **Authorization Checks:** Pundit policies enforce event-level access control
4. **File Validation:** Only `.xlsx` files are accepted for import
5. **Path Security:** Export file paths are validated before download

---

## Support

For questions or issues:
- Check the [Swagger API Documentation](https://api.eventzflow.com/api-docs)
- Review test specs: `spec/requests/v1/tickets_spec.rb`
- Contact: support@eventzflow.com

---

## Changelog

### Version 1.0.0 (2025-11-03)
- Initial release
- Excel import functionality
- Excel export with QR codes
- Export history tracking
- Dynamic custom fields support
