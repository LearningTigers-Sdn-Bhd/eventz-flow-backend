# spec/requests/v1/vendor_profiles_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::VendorProfiles', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:organizer_creator) { create(:user, role: :organizer) }
  let(:other_organizer) { create(:user, role: :organizer) }
  let(:event_admin_user) { create(:user, role: :member) }
  let(:vendor_user) { create(:user, role: :vendor, created_by: organizer_creator) }
  let(:non_vendor_user) { create(:user, role: :member) }
  let(:event) { create(:event) }
  let!(:event_admin_assignment) { create(:event_assignment, event: event, user: event_admin_user, role: 'event_admin') }
  let!(:event_vendor_assignment) { create(:event_vendor, event: event, vendor: vendor_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_creator_token) { JwtService.generate_tokens(organizer_creator)[:access_token] }
  let(:other_organizer_token) { JwtService.generate_tokens(other_organizer)[:access_token] }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin_user)[:access_token] }
  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }
  let(:non_vendor_token) { JwtService.generate_tokens(non_vendor_user)[:access_token] }

  # --- Setup Vendor Profile ---
  # Note: vendor_profile is automatically created when vendor_user is created
  let(:vendor_profile) { vendor_user.vendor_profile }

  path '/v1/vendor_profile' do
    parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

    get 'Get vendor profile' do
      tags 'Vendor Profiles'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      response '200', 'Vendor profile retrieved successfully' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 vendor_id: { type: :integer },
                 image_url: { type: :string, nullable: true },
                 description: { type: :string, nullable: true },
                 category: { type: :string, nullable: true },
                 person_in_charge: { type: :string, nullable: true },
                 address: { type: :string, nullable: true },
                 notes: { type: :string, nullable: true },
                 created_at: { type: :string, format: :date_time },
                 updated_at: { type: :string, format: :date_time },
                 vendor: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     full_name: { type: :string },
                     email: { type: :string },
                     phone: { type: :string, nullable: true }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{vendor_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor_id']).to eq(vendor_user.id)
          expect(data['vendor']).to be_present
        end
      end

      response '403', 'Forbidden - not a vendor' do
        let(:Authorization) { "Bearer #{non_vendor_token}" }

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end
    end

    patch 'Update vendor profile (own)' do
      tags 'Vendor Profiles'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :vendor_profile, in: :body, schema: {
        type: :object,
        properties: {
          vendor_profile: {
            type: :object,
            properties: {
              image: { type: :file, nullable: true, description: 'Vendor profile image' },
              remove_image: { type: :boolean, nullable: true, description: 'Set to true to remove image' },
              description: { type: :string, nullable: true, example: 'Vendor description' },
              category: { type: :string, nullable: true, example: 'Technology' },
              person_in_charge: { type: :string, nullable: true, example: 'John Doe' },
              address: { type: :string, nullable: true, example: '123 Main St' },
              notes: { type: :string, nullable: true, example: 'Additional notes' }
            }
          }
        },
        required: ['vendor_profile']
      }

      response '200', 'Vendor profile updated successfully' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 vendor_id: { type: :integer },
                 image_url: { type: :string, nullable: true },
                 description: { type: :string, nullable: true },
                 category: { type: :string, nullable: true },
                 person_in_charge: { type: :string, nullable: true },
                 address: { type: :string, nullable: true },
                 notes: { type: :string, nullable: true },
                 created_at: { type: :string, format: :date_time },
                 updated_at: { type: :string, format: :date_time },
                 vendor: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     full_name: { type: :string },
                     email: { type: :string },
                     phone: { type: :string, nullable: true }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:vendor_profile) do
          {
            vendor_profile: {
              description: 'Updated description',
              category: 'Food & Beverage',
              person_in_charge: 'Jane Doe',
              address: '456 New St',
              notes: 'Updated notes'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['description']).to eq('Updated description')
          expect(data['category']).to eq('Food & Beverage')
          expect(data['person_in_charge']).to eq('Jane Doe')
        end
      end

      response '403', 'Forbidden - not a vendor' do
        let(:Authorization) { "Bearer #{non_vendor_token}" }
        let(:vendor_profile) { { vendor_profile: { description: 'Test' } } }

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end

      response '200', 'Vendor profile updated with partial data' do
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:vendor_profile) { { vendor_profile: { category: 'Updated Category' } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['category']).to eq('Updated Category')
        end
      end
    end
  end

  path '/v1/vendors/{vendor_id}/profile' do
    parameter name: 'vendor_id', in: :path, type: :integer, description: 'Vendor ID'
    parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

    get 'Get vendor profile by ID (organizer/org_owner - same action as vendor)' do
      tags 'Vendor Profiles'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      response '200', 'Vendor profile retrieved by org owner' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 vendor_id: { type: :integer },
                 image_url: { type: :string, nullable: true },
                 description: { type: :string, nullable: true },
                 category: { type: :string, nullable: true },
                 person_in_charge: { type: :string, nullable: true },
                 address: { type: :string, nullable: true },
                 notes: { type: :string, nullable: true },
                 created_at: { type: :string, format: :date_time },
                 updated_at: { type: :string, format: :date_time },
                 vendor: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     full_name: { type: :string },
                     email: { type: :string },
                     phone: { type: :string, nullable: true },
                     created_by_id: { type: :integer, nullable: true }
                   }
                 }
               }

        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor_id']).to eq(vendor_user.id)
          expect(data['vendor']).to be_present
        end
      end

      response '200', 'Vendor profile retrieved by creator organizer' do
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{organizer_creator_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor_id']).to eq(vendor_user.id)
        end
      end

      response '200', 'Vendor profile retrieved by event admin for assigned vendor' do
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{event_admin_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor_id']).to eq(vendor_user.id)
          expect(data['vendor']['id']).to eq(vendor_user.id)
        end
      end

      response '403', 'Forbidden - organizer who did not create vendor' do
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{other_organizer_token}" }

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end

      response '404', 'Vendor not found' do
        let(:vendor_id) { 99_999 }
        let(:Authorization) { "Bearer #{org_owner_token}" }
        run_test!
      end
    end

    patch 'Update vendor profile by ID (organizer/org_owner - same action as vendor)' do
      tags 'Vendor Profiles'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :vendor_profile, in: :body, schema: {
        type: :object,
        properties: {
          vendor_profile: {
            type: :object,
            properties: {
              image: { type: :file, nullable: true, description: 'Vendor profile image' },
              remove_image: { type: :boolean, nullable: true, description: 'Set to true to remove image' },
              description: { type: :string, nullable: true },
              category: { type: :string, nullable: true },
              person_in_charge: { type: :string, nullable: true },
              address: { type: :string, nullable: true },
              notes: { type: :string, nullable: true }
            }
          }
        },
        required: ['vendor_profile']
      }

      response '200', 'Vendor profile updated by org owner' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 vendor_id: { type: :integer },
                 image_url: { type: :string, nullable: true },
                 description: { type: :string, nullable: true },
                 category: { type: :string, nullable: true },
                 person_in_charge: { type: :string, nullable: true },
                 address: { type: :string, nullable: true },
                 notes: { type: :string, nullable: true },
                 created_at: { type: :string, format: :date_time },
                 updated_at: { type: :string, format: :date_time },
                 vendor: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     full_name: { type: :string },
                     email: { type: :string },
                     phone: { type: :string, nullable: true },
                     created_by_id: { type: :integer, nullable: true }
                   }
                 }
               }

        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:vendor_profile) do
          {
            vendor_profile: {
              category: 'Updated by Admin',
              description: 'Admin updated'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['category']).to eq('Updated by Admin')
          expect(data['description']).to eq('Admin updated')
        end
      end

      response '200', 'Vendor profile updated by creator organizer' do
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{organizer_creator_token}" }
        let(:vendor_profile) do
          {
            vendor_profile: {
              category: 'Updated by Creator'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['category']).to eq('Updated by Creator')
        end
      end

      response '403', 'Forbidden - organizer who did not create vendor' do
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{other_organizer_token}" }
        let(:vendor_profile) { { vendor_profile: { category: 'Test' } } }

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end
    end
  end
end
