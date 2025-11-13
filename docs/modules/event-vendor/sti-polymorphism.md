# STI Polymorphism for EventVendor

## Overview

The EventVendor model uses Single Table Inheritance (STI) to support two distinct vendor types:
- **Exhibitor**: Used when `event.use_ticket = true`
- **Merchant**: Used when `event.use_ticket = false`

This allows the system to handle different vendor requirements based on the event type while maintaining a unified vendor management interface.

## Architecture

### Type Selection

The vendor type is automatically determined by the `event.use_ticket` flag:
- When `event.use_ticket = true`: Creates an `Exhibitor`
- When `event.use_ticket = false`: Creates a `Merchant`

This determination happens in the `EventVendorService.create` method and is transparent to the API consumer.

### ExhibitorOwner Model

Exhibitors require an `ExhibitorOwner` relationship. The `ExhibitorOwner` model represents an organization or entity that owns/manages multiple exhibitors. This allows for grouping exhibitors under a single owner.

**ExhibitorOwner Fields:**
- `name` (required): Name of the exhibitor owner
- `description` (optional): Description of the owner
- `contact_email` (optional): Contact email
- `contact_phone` (optional): Contact phone

## Differences Between Exhibitor and Merchant

### Exhibitor

- **Required Fields**: None additional (inherits base EventVendor requirements)
- **Optional Fields**: `exhibitor_owner_id` (can be independent or owned)
- **Use Case**: Ticket-based events where vendors can be independent or organized under exhibitor owners
- **Associations**: Belongs to `ExhibitorOwner` (optional)
- **Validation**: `exhibitor_owner_id` is optional, but if provided must reference existing ExhibitorOwner
- **Scopes**: `independent`, `owned`, `owned_by(exhibitor_owner)`
- **Helper Methods**: `independent?`, `owned?`

### Merchant

- **Required Fields**: None additional (inherits base EventVendor requirements)
- **Use Case**: Non-ticket events (stamp-based events)
- **Associations**: None additional
- **Validation**: No additional validations (base EventVendor validations apply)

## API Usage

### Creating an Exhibitor

When creating a vendor for an event with `use_ticket = true`, the system automatically creates an Exhibitor. The `exhibitor_owner_id` is optional - you can create independent exhibitors or assign them to an owner:

#### With Owner

```json
POST /v1/events/{event_id}/vendors
{
  "vendor": {
    "full_name": "John Doe",
    "email": "vendor@example.com",
    "password": "securepassword",
    "password_confirmation": "securepassword",
    "redirect_url": "https://example.com",
    "exhibitor_owner_id": 1
  }
}
```

**Response:**
```json
{
  "id": 1,
  "event_id": 1,
  "vendor_id": 1,
  "type": "Exhibitor",
  "redirect_url": "https://example.com",
  "vendor": { ... },
  "exhibitor_owner": {
    "id": 1,
    "name": "Exhibitor Owner Inc",
    "description": "Description",
    "contact_email": "contact@example.com",
    "contact_phone": "+1234567890"
  }
}
```

#### Independent (Without Owner)

```json
POST /v1/events/{event_id}/vendors
{
  "vendor": {
    "full_name": "Independent Vendor",
    "email": "independent@example.com",
    "password": "securepassword",
    "password_confirmation": "securepassword",
    "redirect_url": "https://example.com"
  }
}
```

**Response:**
```json
{
  "id": 2,
  "event_id": 1,
  "vendor_id": 2,
  "type": "Exhibitor",
  "redirect_url": "https://example.com",
  "vendor": { ... },
  "exhibitor_owner": null
}
```

### Creating a Merchant

When creating a vendor for an event with `use_ticket = false`, the system automatically creates a Merchant. The `exhibitor_owner_id` parameter is ignored if provided:

```json
POST /v1/events/{event_id}/vendors
{
  "vendor": {
    "full_name": "Jane Doe",
    "email": "merchant@example.com",
    "password": "securepassword",
    "password_confirmation": "securepassword",
    "redirect_url": "https://example.com"
  }
}
```

**Response:**
```json
{
  "id": 2,
  "event_id": 2,
  "vendor_id": 2,
  "type": "Merchant",
  "redirect_url": "https://example.com",
  "vendor": { ... },
  "exhibitor_owner": null
}
```

### Error Handling

#### Invalid exhibitor_owner_id

If you provide an invalid `exhibitor_owner_id`:

**Response (422):**
```json
{
  "error": "Validation Error",
  "errors": ["ExhibitorOwner not found"]
}
```

**Note**: `exhibitor_owner_id` is optional - you can create independent exhibitors without an owner. The error only occurs if you provide an `exhibitor_owner_id` that doesn't exist.

## Database Schema

### event_vendors table

- `id`: Primary key
- `event_id`: Foreign key to events
- `vendor_id`: Foreign key to users (vendor role)
- `type`: STI type column ('Exhibitor' or 'Merchant')
- `exhibitor_owner_id`: Foreign key to exhibitor_owners (nullable, only for Exhibitor)
- `redirect_url`: Redirect URL for vendor
- `poster_url`: Optional poster URL
- `created_at`, `updated_at`: Timestamps

### exhibitor_owners table

- `id`: Primary key
- `name`: Name of the exhibitor owner (required)
- `description`: Description (optional)
- `contact_email`: Contact email (optional)
- `contact_phone`: Contact phone (optional)
- `created_at`, `updated_at`: Timestamps

## Model Methods

### EventVendor.create_for_event

Class method that automatically creates the appropriate vendor type based on event:

```ruby
event = Event.find(1)
vendor = User.find(1)
event_vendor = EventVendor.create_for_event(event, vendor, {
  redirect_url: 'https://example.com',
  exhibitor_owner_id: 1 # Only used if event.use_ticket = true
})
```

### Scopes

```ruby
# Get all exhibitors
EventVendor.exhibitors

# Get all merchants
EventVendor.merchants

# Get exhibitors owned by a specific owner
Exhibitor.owned_by(exhibitor_owner)

# Get independent exhibitors (no owner)
Exhibitor.independent

# Get owned exhibitors (have an owner)
Exhibitor.owned
```

### Helper Methods

```ruby
exhibitor = Exhibitor.find(1)

# Check if exhibitor is independent
exhibitor.independent?  # => true/false

# Check if exhibitor is owned
exhibitor.owned?  # => true/false

# Get owner name (returns nil if independent)
exhibitor.exhibitor_owner_name  # => "Owner Name" or nil
```

### Event Model

```ruby
# Get vendors by type
event.exhibitors  # Returns Exhibitor records
event.merchants   # Returns Merchant records

# Create vendor (automatically determines type)
event.create_vendor(vendor, attributes)
```

## Migration Guide

### Existing Data

If you have existing `event_vendor` records, they will be automatically backfilled based on their event's `use_ticket` flag:
- Records with `event.use_ticket = true` → Type set to 'Exhibitor'
- Records with `event.use_ticket = false` → Type set to 'Merchant'

**Note**: Existing Exhibitor records can remain independent (without `exhibitor_owner_id`) or be assigned to an ExhibitorOwner. Since `exhibitor_owner_id` is optional, existing records without an owner will automatically become independent exhibitors. If you want to assign them to owners, you can:
1. Create ExhibitorOwner records
2. Update existing Exhibitor records with appropriate `exhibitor_owner_id` (optional)

### Updating Existing Code

If you have code that directly creates `EventVendor` records, update it to use the STI classes or the `create_for_event` method:

```ruby
# Old way
EventVendor.create(event: event, vendor: vendor, redirect_url: url)

# New way (recommended)
EventVendor.create_for_event(event, vendor, redirect_url: url)

# Or explicitly use the type
Exhibitor.create(event: event, vendor: vendor, redirect_url: url, exhibitor_owner: owner)
Merchant.create(event: event, vendor: vendor, redirect_url: url)
```

## Best Practices

1. **Always use `EventVendorService.create`** for creating vendors through the API
2. **Check event.use_ticket** before creating vendors to know which type will be created
3. **Create ExhibitorOwner records first** if you want to assign exhibitors to owners (optional)
4. **Use scopes** to filter vendors by type when querying (`exhibitors`, `merchants`, `independent`, `owned`)
5. **Include exhibitor_owner in API responses** for Exhibitor types (will be null for independent exhibitors)
6. **Use helper methods** (`independent?`, `owned?`) to check exhibitor status
7. **Independent exhibitors** are useful for solo vendors or vendors that don't belong to an organization

## Future Extensions

The Merchant model is a base implementation that can be extended in the future with additional features specific to non-ticket events. The STI structure makes it easy to add Merchant-specific functionality without affecting Exhibitor behavior.
