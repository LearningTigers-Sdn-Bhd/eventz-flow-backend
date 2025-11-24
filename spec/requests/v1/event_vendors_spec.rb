# spec/requests/v1/event_vendors_spec.rb
require 'swagger_helper'

RSpec.describe 'Event Vendors Management', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  EVENT_VENDOR_ERROR_SCHEMA = {
    type: :object,
    properties: {
      error: { type: :string, example: 'Forbidden' },
      message: { type: :string, example: 'Only event admins can perform this action.' }
    },
    required: %w[error message]
  }.freeze

  VENDOR_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer },
      event_id: { type: :integer },
      vendor_id: { type: :integer },
      type: { type: :string, enum: ['Exhibitor', 'Merchant'], description: 'Vendor type based on event.use_ticket' },
      redirect_url: { type: :string },
      poster_url: { type: :string, nullable: true },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time },
      vendor: {
        type: :object,
        properties: {
          id: { type: :integer },
          email: { type: :string },
          full_name: { type: :string, nullable: true },
          phone: { type: :string, nullable: true },
          role: { type: :string },
          status: { type: :string }
        }
      },
      exhibitor_owner: {
        type: :object,
        nullable: true,
        description: 'ExhibitorOwner object (only present for Exhibitor type)',
        properties: {
          id: { type: :integer },
          name: { type: :string },
          description: { type: :string, nullable: true },
          contact_email: { type: :string, nullable: true },
          contact_phone: { type: :string, nullable: true }
        }
      }
    },
    required: %w[id event_id vendor_id type redirect_url]
  }.freeze

  # ============================================================
  # Setup
  # ============================================================
  let(:event) { create(:event, title: 'Tech Conference 2024') }
  let(:org_owner) { create(:org_owner) }
  let(:event_admin_user) { create(:member_user) }
  let(:non_admin_user) { create(:member_user) }
  let(:vendor_user) { create(:member_user) }

  # Create event admin assignment
  let!(:event_admin_assignment) do
    create(:event_assignment, event: event, user: event_admin_user, role: 'event_admin')
  end

  # use the real encoder to generate valid tokens
  let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
  let(:auth_header_non_admin) { "Bearer #{JwtService.generate_tokens(non_admin_user)[:access_token]}" }
  let(:auth_header_org_owner) { "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" }

  # ============================================================
  # GET /v1/events/{event_id}/vendors
  # ============================================================
  path '/v1/events/{event_id}/vendors' do
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'ID of the parent event'

    get 'Lists all vendors assigned to an event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'

      let(:event_id) { event.id }
      let(:Authorization) { auth_header_event_admin }

      before do
        # Create some event vendors for the event
        vendor1 = create(:user, role: :vendor, full_name: 'John Doe', email: 'vendor1@example.com')
        vendor2 = create(:user, role: :vendor, full_name: 'Jane Smith', email: 'vendor2@example.com')
        create(:merchant, event: event, vendor: vendor1, redirect_url: 'https://example.com/vendor1')
        create(:merchant, event: event, vendor: vendor2, redirect_url: 'https://example.com/vendor2')
      end

      response '200', 'Returns list of vendors assigned to the event' do
        schema type: :array,
          items: VENDOR_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
          expect(data.length).to eq(2)
          expect(data.first).to have_key('vendor')
          expect(data.first).to have_key('type')
          expect(data.first['vendor_id']).to be_present
          expect(data.first['type']).to eq('Merchant')
        end
      end

      response '404', 'Event not found' do
        let(:Authorization) { auth_header_event_admin }
        let(:event_id) { 99999 }
        schema type: :object,
          properties: {
            error: { type: :string },
            message: { type: :string }
          }
        run_test!
      end
    end

    # ============================================================
    # POST /v1/events/{event_id}/vendors
    # ============================================================
    post 'Creates a new vendor for an event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          vendor: {
            type: :object,
            properties: {
              vendor_id: { type: :integer, description: 'ID of existing vendor user (optional)' },
              full_name: { type: :string, example: 'John Doe' },
              email: { type: :string, example: 'vendor@example.com' },
              phone: { type: :string, nullable: true, example: '+1234567890' },
              password: { type: :string, example: 'securepassword' },
              password_confirmation: { type: :string, example: 'securepassword' },
              redirect_url: { type: :string, example: 'https://example.com', description: 'Redirect URL for vendor' },
              exhibitor_owner_id: { type: :integer, nullable: true, description: 'ID of ExhibitorOwner (required for Exhibitor type when event.use_ticket=true, ignored for Merchant type)' }
            },
            required: %w[full_name password password_confirmation]
          }
        },
        required: ['vendor']
      }

      let(:event_id) { event.id }
      let(:Authorization) { auth_header_event_admin }

      response '201', 'Vendor created successfully with provided email (organizer creates new vendor)' do
        let(:event) { create(:event, title: 'Tech Conference 2024', use_ticket: false) }
        let(:event_admin_user) { create(:organizer_user) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: 'vendor@example.com',
              phone: '+1234567890',
              password: 'securepassword123',
              password_confirmation: 'securepassword123',
              redirect_url: 'https://example.com'
            }
          }
        end

        schema VENDOR_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor']['email']).to eq('vendor@example.com')
          expect(data['vendor']['full_name']).to eq('John Doe')
          expect(data['vendor_id']).to be_present
          expect(data['vendor']['role']).to eq('vendor')
          expect(data['type']).to eq('Merchant') # Default type for use_ticket: false
        end
      end

      response '201', 'Vendor assigned when vendor_id provided' do
        let(:event) { create(:event, title: 'Tech Conference 2024', use_ticket: false) }
        let!(:existing_vendor) { create(:user, role: :vendor, email: 'existing_vendor@example.com', full_name: 'Existing Vendor') }
        let(:body) do
          {
            vendor: {
              vendor_id: existing_vendor.id,
              redirect_url: 'https://example.com'
            }
          }
        end

        schema VENDOR_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor']['id']).to eq(existing_vendor.id)
          expect(data['vendor']['email']).to eq('existing_vendor@example.com')
          expect(data['vendor_id']).to eq(existing_vendor.id)
          expect(data['type']).to eq('Merchant') # Default type for use_ticket: false
        end
      end

      response '201', 'Vendor created with auto-generated email' do
        let(:event_admin_user) { create(:organizer_user) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: '',
              phone: '+1234567890',
              password: 'securepassword123',
              password_confirmation: 'securepassword123',
              redirect_url: 'https://example.com'
            }
          }
        end

        schema VENDOR_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor']['email']).to match(/vendor_tech_conference_2024_john(@|_00@)eventzflow\.com/)
          expect(data['vendor']['full_name']).to eq('John Doe')
          expect(data['vendor_id']).to be_present
          expect(data['vendor']['role']).to eq('vendor')
        end
      end

      response '422', 'Error when assigning non-vendor user' do
        let!(:existing_user) { create(:member_user, email: 'existing@example.com', full_name: 'Existing User') }
        let(:event_admin_user) { create(:organizer_user) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
        let(:body) do
          {
            vendor: {
              full_name: 'Existing User',
              email: 'existing@example.com',
              password: 'securepassword123',
              password_confirmation: 'securepassword123'
            }
          }
        end

        schema type: :object,
          properties: {
            error: { type: :string },
            errors: { type: :array, items: { type: :string } }
          }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to include('User exists but is not a vendor')
        end
      end

      response '201', 'Vendor created with auto-generated email increment when duplicate exists' do
        let(:event_admin_user) { create(:organizer_user) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
        let!(:existing_user) do
          create(:user, role: :vendor, email: 'vendor_tech_conference_2024_john@eventzflow.com', full_name: 'Existing User')
        end
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: '',
              phone: '+1234567890',
              password: 'securepassword123',
              password_confirmation: 'securepassword123',
              redirect_url: 'https://example.com'
            }
          }
        end

        schema VENDOR_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          # Should use _00 increment since base email exists
          expect(data['vendor']['email']).to match(/vendor_tech_conference_2024_john_\d{2}@eventzflow\.com/)
          expect(data['vendor']['full_name']).to eq('John Doe')
          expect(data['vendor_id']).to be_present
          expect(data['vendor']['role']).to eq('vendor')
        end
      end

      response '422', 'Validation error - password mismatch' do
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: 'vendor@example.com',
              password: 'securepassword123',
              password_confirmation: 'differentpassword'
            }
          }
        end

        schema type: :object,
          properties: {
            error: { type: :string },
            errors: { type: :array, items: { type: :string } }
          }

        run_test!
      end

      response '403', 'Forbidden for non-event-admin' do
        let(:Authorization) { auth_header_non_admin }
        let(:body) do
          {
            vendor: {
              full_name: 'John Doe',
              email: 'vendor@example.com',
              password: 'securepassword123',
              password_confirmation: 'securepassword123'
            }
          }
        end

        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end

      # ============================================================
      # Exhibitor Creation Tests (event.use_ticket = true)
      # ============================================================
      context 'when event.use_ticket is true (Exhibitor)' do
        let(:event) { create(:event, title: 'Exhibition Event', use_ticket: true) }
        let(:exhibitor_owner) { create(:exhibitor_owner, name: 'Exhibitor Owner Inc') }
        let(:event_admin_user) { create(:organizer_user) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }

        response '201', 'Exhibitor created successfully with exhibitor_owner_id' do
          let(:body) do
            {
              vendor: {
                full_name: 'Exhibitor Vendor',
                email: 'exhibitor@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://exhibitor.com',
                exhibitor_owner_id: exhibitor_owner.id
              }
            }
          end

          schema VENDOR_RESPONSE_SCHEMA

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['type']).to eq('Exhibitor')
            expect(data['exhibitor_owner']).to be_present
            expect(data['exhibitor_owner']['id']).to eq(exhibitor_owner.id)
            expect(data['exhibitor_owner']['name']).to eq('Exhibitor Owner Inc')
            expect(data['vendor']['email']).to eq('exhibitor@example.com')
          end
        end

        response '201', 'Exhibitor created successfully without exhibitor_owner_id (independent exhibitor)' do
          let(:body) do
            {
              vendor: {
                full_name: 'Independent Exhibitor',
                email: 'independent@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://exhibitor.com'
              }
            }
          end

          schema VENDOR_RESPONSE_SCHEMA

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['type']).to eq('Exhibitor')
            expect(data['exhibitor_owner']).to be_nil
            expect(data['vendor']['email']).to eq('independent@example.com')
          end
        end

        response '422', 'Exhibitor creation fails with invalid exhibitor_owner_id' do
          let(:body) do
            {
              vendor: {
                full_name: 'Exhibitor Vendor',
                email: 'exhibitor@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://exhibitor.com',
                exhibitor_owner_id: 99999
              }
            }
          end

          schema type: :object,
            properties: {
              error: { type: :string },
              errors: { type: :array, items: { type: :string } }
            }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['errors']).to include('ExhibitorOwner not found')
          end
        end

        response '201', 'Exhibitor assigned when vendor_id provided' do
          let!(:existing_vendor) { create(:user, role: :vendor, email: 'existing_exhibitor@example.com', full_name: 'Existing Exhibitor') }
          let(:body) do
            {
              vendor: {
                vendor_id: existing_vendor.id,
                redirect_url: 'https://exhibitor.com',
                exhibitor_owner_id: exhibitor_owner.id
              }
            }
          end

          schema VENDOR_RESPONSE_SCHEMA

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['type']).to eq('Exhibitor')
            expect(data['exhibitor_owner']).to be_present
            expect(data['vendor']['id']).to eq(existing_vendor.id)
          end
        end
      end

      # ============================================================
      # Merchant Creation Tests (event.use_ticket = false)
      # ============================================================
      context 'when event.use_ticket is false (Merchant)' do
        let(:event) { create(:event, title: 'Merchant Event', use_ticket: false) }
        let(:event_admin_user) { create(:organizer_user) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }

        response '201', 'Merchant created successfully without exhibitor_owner_id' do
          let(:body) do
            {
              vendor: {
                full_name: 'Merchant Vendor',
                email: 'merchant@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://merchant.com'
              }
            }
          end

          schema VENDOR_RESPONSE_SCHEMA

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['type']).to eq('Merchant')
            expect(data['exhibitor_owner']).to be_nil
            expect(data['vendor']['email']).to eq('merchant@example.com')
          end
        end

        response '201', 'Merchant created and ignores exhibitor_owner_id if provided' do
          let(:exhibitor_owner) { create(:exhibitor_owner) }
          let(:body) do
            {
              vendor: {
                full_name: 'Merchant Vendor',
                email: 'merchant2@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://merchant.com',
                exhibitor_owner_id: exhibitor_owner.id # Should be ignored
              }
            }
          end

          schema VENDOR_RESPONSE_SCHEMA

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['type']).to eq('Merchant')
            expect(data['exhibitor_owner']).to be_nil
          end
        end
      end
    end
  end


  # ============================================================
  # DELETE /v1/events/{event_id}/vendors/{id}
  # ============================================================
  path '/v1/events/{event_id}/vendors/{id}' do
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: :id, in: :path, type: :integer, required: true, description: 'Vendor Assignment ID'

    delete 'Removes a vendor from an event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      let(:event_id) { event.id }
      let(:Authorization) { auth_header_event_admin }
      let!(:event_vendor) do
        vendor = create(:user, role: :vendor, full_name: 'John Doe', email: 'vendor@example.com')
        create(:merchant, event: event, vendor: vendor, redirect_url: 'https://example.com')
      end
      let(:id) { event_vendor.id }

      response '204', 'Vendor removed successfully' do
        run_test! do
          expect(EventVendor.find_by(id: event_vendor.id)).to be_nil
        end
      end

      response '403', 'Forbidden for non-event-admin' do
        let(:Authorization) { auth_header_non_admin }
        
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string }
               }

        run_test!
      end

      response '404', 'Event vendor not found' do
        let(:id) { 99999 }
        schema type: :object,
          properties: {
            error: { type: :string },
            message: { type: :string }
          }
        run_test!
      end
    end
  end
end
