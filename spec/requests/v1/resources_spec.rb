require 'swagger_helper'

RESOURCE_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    title: { type: :string },
    article: { type: :string },
    slug: { type: :string },
    meta_description: { type: :string },
    status: { type: :string },
    is_gated: { type: :boolean },
    is_official: { type: :boolean },
    view_counts: { type: :integer },
    published_at: { type: :string, format: :date_time, nullable: true },
    resource_topic_id: { type: :integer },
    resource_category_id: { type: :integer },
    resource_media_type_id: { type: :integer },
    user_id: { type: :integer },
    created_at: { type: :string, format: :date_time },
    updated_at: { type: :string, format: :date_time }
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

      response(200, 'successful for visitor') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: RESOURCE_SCHEMA
                 }
               }
        
        before do
          create(:resource, status: :published)
          create(:resource, status: :draft)
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          # Visitors should only see published resources
          expect(data.any? { |r| r['status'] == 'published' }).to be true
          expect(data.any? { |r| r['status'] == 'draft' }).to be false
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

      response(200, 'successful for writer') do
        let(:Authorization) { auth_headers(writer)['Authorization'] }
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: RESOURCE_SCHEMA
                 }
               }

        before do
          create(:resource, status: :published) # visible to all
          create(:resource, user: writer, status: :draft) # writer's own draft
          create(:resource, status: :draft) # another user's draft, should not be visible
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          # Writer should see the published one AND their own draft
          expect(data.size).to be >= 2
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
              status: { type: :string, enum: %w[draft published] },
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
          expect(data['user_id']).to eq(writer.id)
        end
      end

      response(403, 'unauthorized user') do
        let(:Authorization) { auth_headers(regular_user)['Authorization'] }
        let(:resource_params) { { resource: { title: "Fail" } } }
        run_test!
      end
    end
  end

  path '/v1/resources/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'ID or Slug'

    let(:resource_item) { create(:resource, user: writer, status: :published, resource_topic: resource_topic, resource_category: resource_category, resource_media_type: resource_media_type) }
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
              status: { type: :string, enum: %w[published draft] }
            }
          }
        }
      }

      response(200, 'status updated') do
        let(:Authorization) { auth_headers(org_owner)['Authorization'] }
        let(:resource_params) { { resource: { status: 'published' } } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['status']).to eq('published')
          expect(data['published_at']).to be_present
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
end
