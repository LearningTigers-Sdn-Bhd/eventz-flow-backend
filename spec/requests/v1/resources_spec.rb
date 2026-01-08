require 'swagger_helper'

RESOURCE_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    title: { type: :string },
    slug: { type: :string },
    meta_description: { type: :string, nullable: true },
    status: { type: :string, enum: %w[draft pending_review published rejected archived] },
    is_gated: { type: :boolean },
    is_official: { type: :boolean },
    rejection_reason: { type: :string, nullable: true },
    view_counts: { type: :integer },
    published_at: { type: :string, format: :date_time, nullable: true },
    created_at: { type: :string, format: :date_time },
    updated_at: { type: :string, format: :date_time },
    deleted_at: { type: :string, format: :date_time, nullable: true },
    cover_image_url: { type: :string, nullable: true },
    topic: { 
      type: :object, 
      nullable: true,
      properties: {
        id: { type: :integer },
        name: { type: :string }
      }
    },
    category: { 
      type: :object, 
      nullable: true,
      properties: {
        id: { type: :integer },
        name: { type: :string }
      }
    },
    media_type: { 
      type: :object, 
      nullable: true,
      properties: {
        id: { type: :integer },
        name: { type: :string }
      }
    },
    article: { type: :string },
    author: {
      type: :object,
      nullable: true,
      properties: {
        id: { type: :integer },
        full_name: { type: :string },
        email: { type: :string }
      }
    }
  }
}.freeze

PAGINATION_SCHEMA = {
  type: :object,
  properties: {
    current_page: { type: :integer },
    total_pages: { type: :integer },
    total_count: { type: :integer },
    per_page: { type: :integer },
    prev_page: { type: :integer, nullable: true },
    next_page: { type: :integer, nullable: true },
    first_page: { type: :integer },
    last_page: { type: :integer },
    from: { type: :integer },
    to: { type: :integer }
  }
}.freeze

RSpec.describe "V1::Resources", type: :request do

  # Users
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:writer) { create(:user, role: :member) }
  let(:regular_user) { create(:user, role: :member) }
  before { create(:resource_write_permission, user: writer) }

  # Shared Dependencies
  let(:resource_topic) { create(:resource_topic) }
  let(:resource_category) { create(:resource_category) }
  let(:resource_media_type) { create(:resource_media_type) }

  # --- Public Endpoints ---

  path '/v1/resources/public' do
    get('list resources public') do
      tags 'Resources CMS'
      produces 'application/json'
      security [] # No auth required
      parameter name: :page, in: :query, type: :integer, description: 'Page number', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page', required: false

      response(200, 'successful for visitor') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: RESOURCE_SCHEMA
                 },
                 pagination: PAGINATION_SCHEMA
               }
        
        before do
          create_list(:resource, 5, status: :published)
          create(:resource, status: :draft)
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          data = json['data']
          # Visitors should only see published resources
          expect(data.all? { |r| r['status'] == 'published' }).to be true
          expect(json).to have_key('pagination')
        end
      end
    end
  end

  path '/v1/resources/{id}/public' do
    parameter name: :id, in: :path, type: :string, description: 'ID or Slug'

    let(:resource_item) { create(:resource, user: writer, status: :published, resource_topic: resource_topic, resource_category: resource_category, resource_media_type: resource_media_type) }
    let(:id) { resource_item.id }

    get('show resource public') do
      tags 'Resources CMS'
      produces 'application/json'
      security [] # No auth required

      response(200, 'successful') do
        schema type: :object, properties: { data: RESOURCE_SCHEMA }
        run_test!
      end

      response(404, 'not found') do
        let(:id) { 'non-existent' }
        run_test!
      end
    end
  end

  # --- Authenticated Endpoints ---

  path '/v1/resources' do
    get('list resources authenticated') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :page, in: :query, type: :integer, description: 'Page number', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page', required: false

      response(200, 'successful for writer') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:page) { 1 }
        let(:per_page) { 10 }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: RESOURCE_SCHEMA
                 },
                 pagination: PAGINATION_SCHEMA
               }

        before do
          create(:resource, status: :published) # visible to all
          create(:resource, user: writer, status: :draft) # writer's own draft
          create(:resource, status: :draft) # another user's draft, should not be visible
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          data = json['data']
          pagination = json['pagination']
          
          # Writer should see the published one AND their own draft
          expect(data.size).to be >= 2
          expect(pagination['current_page']).to eq(1)
        end
      end
    end

    post('create resource') do
      tags 'Resources CMS'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :resource_params, in: :body, schema: {
        type: :object,
        properties: {
          resource: {
            type: :object,
            required: %i[title article resource_topic_id resource_category_id resource_media_type_id],
            properties: {
              title: { type: :string },
              article: { type: :string },
              meta_description: { type: :string },
              resource_topic_id: { type: :integer },
              resource_category_id: { type: :integer },
              resource_media_type_id: { type: :integer },
              status: { type: :string, enum: %w[draft pending_review published rejected] },
              is_gated: { type: :boolean }
            }
          }
        }
      }

      response(201, 'resource created') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:resource_params) { { 
          resource: {
            title: "New Article",
            article: "Content here",
            resource_topic_id: resource_topic.id,
            resource_category_id: resource_category.id,
            resource_media_type_id: resource_media_type.id,
            status: 'draft',
            is_gated: false
          }
        } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['title']).to eq("New Article")
          expect(data['author']['id']).to eq(writer.id)
        end
      end

      response(403, 'unauthorized user') do
        let(:Authorization) { auth_headers(regular_user)['Authorization'] }
        let(:resource_params) { { resource: { title: "Fail" } } }
        run_test!
      end
    end
  end

  path '/v1/resources/owner' do
    get('list all resources (owner only)') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response(200, 'successful for owner') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        schema type: :object,
               properties: {
                 data: { type: :array, items: RESOURCE_SCHEMA },
                 pagination: PAGINATION_SCHEMA
               }
        
        before { create_list(:resource, 3) }
        run_test!
      end

      response(403, 'forbidden for non-owner') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        run_test!
      end
    end
  end

  path '/v1/resources/approval_index' do
    get('list resources pending approval') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response(200, 'successful for admin') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        schema type: :object,
               properties: {
                 data: { type: :array, items: RESOURCE_SCHEMA },
                 pagination: PAGINATION_SCHEMA
               }
        
        before { create_list(:resource, 2, status: :pending_review) }
        run_test!
      end

      response(403, 'forbidden for writer') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        run_test!
      end
    end
  end

  path '/v1/resources/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'ID or Slug'

    let(:resource_item) { create(:resource, user: writer, status: :draft, resource_topic: resource_topic, resource_category: resource_category, resource_media_type: resource_media_type) }
    let(:id) { resource_item.id }

    get('show resource authenticated') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        schema type: :object, properties: { data: RESOURCE_SCHEMA }
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:id) { 'non-existent' }
        run_test!
      end
    end

    put('update resource') do
      tags 'Resources CMS'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :resource_params, in: :body, schema: {
        type: :object,
        properties: {
          resource: {
            type: :object,
            properties: {
              title: { type: :string },
              article: { type: :string },
              status: { type: :string },
              is_gated: { type: :boolean }
            }
          }
        }
      }

      response(200, 'updated') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:resource_params) { { resource: { title: "Updated Title" } } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['title']).to eq("Updated Title")
        end
      end

      response(403, 'unauthorized update (not owner)') do
        let(:other_resource) { create(:resource, user: org_owner) } # owned by someone else
        let(:id) { other_resource.id }
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:resource_params) { { resource: { title: "Hacked" } } }
        run_test!
      end
    end

    delete('soft delete resource') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'soft deleted') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }

        run_test! do
          expect(Resource.find_by(id: id)).to be_nil # Should not find it with default scope
          expect(Resource.unscoped.find(id).deleted_at).to be_present
        end
      end
    end
  end

  path '/v1/resources/{id}/restore' do
    parameter name: :id, in: :path, type: :string
    
    let(:deleted_resource) { create(:resource, user: writer, deleted_at: Time.current) }
    let(:id) { deleted_resource.id }

    post('restore resource') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'restored') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        
        run_test! do
          expect(Resource.find(id).deleted_at).to be_nil
        end
      end
      
      response(403, 'unauthorized') do
        let(:Authorization) { auth_headers(regular_user)['Authorization'] }
        run_test!
      end
    end
  end

  path '/v1/resources/{id}/force_destroy' do
    parameter name: :id, in: :path, type: :string
    
    let(:resource_item) { create(:resource, user: writer) }
    let(:id) { resource_item.id }

    delete('force destroy resource') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'permanently deleted') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        
        run_test! do
          expect(Resource.unscoped.find_by(id: id)).to be_nil
        end
      end

      response(403, 'unauthorized (writer cannot force destroy)') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        run_test!
      end
    end
  end

  path '/v1/resources/{id}/approval' do
    parameter name: :id, in: :path, type: :string

    let(:draft_resource) { create(:resource, user: writer, status: :draft) }
    let(:id) { draft_resource.id }

    patch('approve/publish resource') do
      tags 'Resources CMS'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :resource_params, in: :body, schema: {
        type: :object,
        properties: {
          resource: {
            type: :object,
            required: [:status],
            properties: {
              status: { type: :string, enum: %w[published draft rejected] },
              rejection_reason: { type: :string }
            }
          }
        }
      }

      response(200, 'status updated (published)') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:resource_params) { { resource: { status: 'published' } } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['status']).to eq('published')
          expect(data['published_at']).to be_present
        end
      end

      response(200, 'status updated (rejected)') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:resource_params) { { resource: { status: 'rejected', rejection_reason: 'Too short' } } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['status']).to eq('rejected')
          expect(data['rejection_reason']).to eq('Too short')
        end
      end

      response(403, 'unauthorized (writer cannot approve own)') do
        # Assuming only admins can approve? 
        # Plan says: "force_destroy, approval -> Admin only."
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        let(:resource_params) { { resource: { status: 'published' } } }
        run_test!
      end
    end
  end

  path '/v1/resources/{id}/duplicate' do
    parameter name: :id, in: :path, type: :string

    let(:resource_item) { create(:resource, user: writer) }
    let(:id) { resource_item.id }

    post('duplicate resource') do
      tags 'Resources CMS'
      produces 'application/json'
      security [bearerAuth: []]

      response(201, 'resource duplicated') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['title']).to start_with('Copy of')
          expect(data['status']).to eq('draft')
        end
      end
    end
  end
end
