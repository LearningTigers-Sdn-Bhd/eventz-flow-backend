# API Pagination Documentation

This document describes how pagination is implemented in the EventzFlow API and how to use it.

## Overview

We use the [Pagy](https://ddnexus.github.io/pagy/) gem for high-performance pagination. Pagination is standardized across the API, providing consistent request parameters and response structures.

## Client Usage

### Request Parameters

To retrieve paginated results, use the following query parameters on supported endpoints (e.g., `GET /v1/resources`):

| Parameter  | Type    | Default | Description                                      |
| :--------- | :------ | :------ | :----------------------------------------------- |
| `page`     | Integer | 1       | The page number to retrieve.                     |
| `per_page` | Integer | 25      | Number of items per page. (Max: 100) |

**Example Request:**

```http
GET /v1/resources?page=2&per_page=10
```

### Response Format

Paginated responses follow a standard JSON structure with a `data` array and a top-level `pagination` object.

**Example Response:**

```json
{
  "success": true,
  "message": "Success",
  "data": [
    {
      "id": 101,
      "title": "Event Planning Guide",
      "status": "published",
      ...
    },
    ...
  ],
  "pagination": {
    "current_page": 2,
    "total_pages": 5,
    "total_count": 50,
    "per_page": 10,
    "prev_page": 1,
    "next_page": 3,
    "first_page": 1,
    "last_page": 5,
    "from": 11,
    "to": 20
  }
}
```

### Pagination Object Fields

| Field          | Type    | Description                                      |
| :------------- | :------ | :----------------------------------------------- |
| `current_page` | Integer | The current page number.                         |
| `total_pages`  | Integer | Total number of pages available.                 |
| `total_count`  | Integer | Total number of records across all pages.        |
| `per_page`     | Integer | Number of items per page (limit).                |
| `prev_page`    | Integer | Previous page number (or null if on first page). |
| `next_page`    | Integer | Next page number (or null if on last page).      |
| `first_page`   | Integer | Always 1.                                        |
| `last_page`    | Integer | The number of the last page.                     |
| `from`         | Integer | Ordinal number of the first item on this page.   |
| `to`           | Integer | Ordinal number of the last item on this page.    |

---

## Backend Implementation Guide

### Configuration

Pagy is configured in `config/initializers/pagy.rb`.
- Default limit: 25
- Max client limit: 100
- Overflow handling: Returns empty page (no error raised).

### Adding Pagination to a Controller

1.  **Include Pagy:** `ApplicationController` already includes `Pagy::Method`.
2.  **Paginate Scope:** Use the `pagy` method in your controller action.
3.  **Render Response:** Use `success_response` with the `pagination` argument.

**Example:**

```ruby
def index
  # 1. Define your scope (e.g., filter, sort)
  resources_scope = Resource.published.order(created_at: :desc)

  # 2. Paginate
  # Use pagination_params to safely extract per_page
  @pagy, @resources = pagy(resources_scope, limit: pagination_params[:per_page])

  # 3. Format Data
  formatted_resources = @resources.map { |r| format_resource(r) }

  # 4. Render
  success_response(data: formatted_resources, pagination: pagy_metadata(@pagy))
end
```

### Helper Methods

`ApplicationController` provides:

-   `pagination_params`: Safely extracts and limits `page` and `per_page` from request params.
-   `pagy_metadata(@pagy)`: Generates the standard pagination hash from the Pagy object.

### Error Handling

-   **Invalid Parameters**: If `page` or `per_page` are invalid (e.g., negative, non-integer), `Pagy::OptionError` is rescued and returns a `400 Bad Request`.
-   **Overflow**: If `page` exceeds `total_pages`, an empty `data` array is returned (configured via `overflow: :empty_page`).
