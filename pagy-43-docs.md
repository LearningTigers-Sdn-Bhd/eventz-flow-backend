# Pagy Backend API Setup Guide

Complete guide for implementing Pagy pagination in Rails API applications.

## Table of Contents
- [Installation](#installation)
- [Basic Configuration](#basic-configuration)
- [Controller Setup](#controller-setup)
- [API Response Format](#api-response-format)
- [Advanced Features](#advanced-features)
- [Error Handling](#error-handling)

## Installation

Add Pagy to your Gemfile:

```ruby
gem 'pagy', '~> 43.2'
```

Run bundle install:

```bash
bundle install
```

## Basic Configuration

Create an initializer file `config/initializers/pagy.rb`:

```ruby
# Pagy initializer file (config/initializers/pagy.rb)

# Default items per page
Pagy::DEFAULT[:items] = 25

# Maximum items per page allowed
Pagy::DEFAULT[:max_items] = 100

# Maximum page number allowed
Pagy::DEFAULT[:max_pages] = 1000

# Set to false if you want to disable the overflow handling
Pagy::DEFAULT[:overflow] = :empty_page
```

## Controller Setup

### Application Controller

Set up the base controller with Pagy support:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Pagy::Method

  # Handle pagination overflow errors
  rescue_from Pagy::OverflowError, with: :handle_page_overflow

  private

  # Error handler for invalid page numbers
  def handle_page_overflow
    render json: {
      error: 'Page number out of range',
      message: 'The requested page does not exist'
    }, status: :bad_request
  end

  # Generate pagination metadata for API responses
  def pagy_metadata(pagy)
    {
      current_page: pagy.page,
      total_pages: pagy.pages,
      total_count: pagy.count,
      per_page: pagy.items,
      prev_page: pagy.prev,
      next_page: pagy.next,
      first_page: 1,
      last_page: pagy.pages,
      from: pagy.from,
      to: pagy.to
    }
  end
end
```

### Resource Controller Example

Example implementation for a products API:

```ruby
# app/controllers/api/v1/products_controller.rb
module Api
  module V1
    class ProductsController < ApplicationController
      # GET /api/v1/products
      def index
        # Basic pagination
        @pagy, @products = pagy(:offset, Product.all, items: params[:per_page] || 20)

        render json: {
          data: @products.as_json(only: [:id, :name, :price, :description]),
          pagination: pagy_metadata(@pagy)
        }
      end

      # GET /api/v1/products/search
      def search
        # Pagination with filtering
        scope = Product.where('name ILIKE ?', "%#{params[:q]}%")
        @pagy, @products = pagy(:offset, scope)

        render json: {
          data: @products,
          pagination: pagy_metadata(@pagy),
          query: params[:q]
        }
      end
    end
  end
end
```

## API Response Format

### Standard Response Structure

```json
{
  "data": [
    {
      "id": 1,
      "name": "Product 1",
      "price": 29.99
    },
    {
      "id": 2,
      "name": "Product 2",
      "price": 39.99
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 10,
    "total_count": 200,
    "per_page": 20,
    "prev_page": null,
    "next_page": 2,
    "first_page": 1,
    "last_page": 10,
    "from": 1,
    "to": 20
  }
}
```

### Making API Requests

Query parameters for pagination:

```bash
# Default pagination
GET /api/v1/products

# Specific page
GET /api/v1/products?page=2

# Custom items per page
GET /api/v1/products?page=1&per_page=50

# Combined with filters
GET /api/v1/products?page=2&per_page=25&category=electronics
```

## Advanced Features

### Using with ActiveRecord Scopes

```ruby
class ProductsController < ApplicationController
  def index
    scope = Product.active
                   .includes(:category)
                   .order(created_at: :desc)

    @pagy, @products = pagy(:offset, scope)

    render json: {
      data: @products.as_json(include: :category),
      pagination: pagy_metadata(@pagy)
    }
  end
end
```

### Keyset Pagination (for better performance)

For large datasets, keyset pagination is more efficient:

```ruby
def index
  # Keyset pagination uses cursor-based approach
  @pagy, @products = pagy(:keyset,
    Product.order(id: :desc),
    items: 20,
    tuple: :id  # The column to use for keyset
  )

  render json: {
    data: @products,
    pagination: {
      next_cursor: @pagy.next,
      prev_cursor: @pagy.prev,
      has_more: @pagy.next.present?
    }
  }
end
```

### Custom Serializers

With active_model_serializers or similar:

```ruby
def index
  @pagy, @products = pagy(:offset, Product.all)

  render json: {
    data: ActiveModelSerializers::SerializableResource.new(
      @products,
      each_serializer: ProductSerializer
    ).as_json,
    pagination: pagy_metadata(@pagy)
  }
end
```

### Pagination with JSONAPI format

```ruby
def index
  @pagy, @products = pagy(:offset, Product.all)

  render json: {
    data: @products.as_json,
    links: {
      self: request.original_url,
      first: url_for(page: 1),
      last: url_for(page: @pagy.pages),
      prev: @pagy.prev ? url_for(page: @pagy.prev) : nil,
      next: @pagy.next ? url_for(page: @pagy.next) : nil
    },
    meta: {
      total_count: @pagy.count,
      page_count: @pagy.pages,
      current_page: @pagy.page,
      per_page: @pagy.items
    }
  }
end
```

## Error Handling

### Validation and Edge Cases

```ruby
class ApplicationController < ActionController::API
  include Pagy::Method

  rescue_from Pagy::OverflowError, with: :handle_page_overflow
  rescue_from Pagy::VariableError, with: :handle_pagy_variable_error

  private

  def handle_page_overflow
    render json: {
      error: 'page_out_of_range',
      message: 'The requested page does not exist'
    }, status: :bad_request
  end

  def handle_pagy_variable_error(exception)
    render json: {
      error: 'invalid_pagination_params',
      message: exception.message
    }, status: :bad_request
  end

  # Sanitize pagination parameters
  def pagination_params
    params.permit(:page, :per_page).tap do |p|
      p[:page] = [p[:page].to_i, 1].max if p[:page].present?
      p[:per_page] = [[p[:per_page].to_i, 100].min, 1].max if p[:per_page].present?
    end
  end
end
```

### Testing Pagination

```ruby
# spec/requests/api/v1/products_spec.rb
require 'rails_helper'

RSpec.describe 'Products API', type: :request do
  describe 'GET /api/v1/products' do
    before do
      create_list(:product, 50)
    end

    it 'returns paginated products' do
      get '/api/v1/products', params: { page: 1, per_page: 20 }

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(20)
      expect(json['pagination']['current_page']).to eq(1)
      expect(json['pagination']['total_count']).to eq(50)
      expect(json['pagination']['total_pages']).to eq(3)
    end

    it 'handles invalid page numbers' do
      get '/api/v1/products', params: { page: 999 }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
```

## Performance Tips

1. **Use includes/joins** to avoid N+1 queries:
```ruby
@pagy, @products = pagy(:offset, Product.includes(:category, :reviews))
```

2. **Use select** to limit columns:
```ruby
@pagy, @products = pagy(:offset, Product.select(:id, :name, :price))
```

3. **Add database indexes** on commonly sorted columns:
```ruby
add_index :products, :created_at
add_index :products, [:category_id, :created_at]
```

4. **Consider keyset pagination** for very large datasets (millions of records)

5. **Cache counts** if they're expensive:
```ruby
@pagy, @products = pagy(:offset, Product.all, count: Rails.cache.fetch('products_count', expires_in: 5.minutes) { Product.count })
```

## Resources

- [Official Pagy Documentation](https://ddnexus.github.io/pagy/)
- [Pagy GitHub Repository](https://github.com/ddnexus/pagy)
- [Pagy API Documentation](https://ddnexus.github.io/pagy/docs/api/)

---

**Version:** Pagy 43.2+
**Last Updated:** January 2026
