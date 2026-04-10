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

  EXHIBITOR_TEAM_MEMBER_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, nullable: true },
      full_name: { type: :string, example: 'Team Member Name' }
    },
    required: %w[full_name]
  }.freeze

  EXHIBITOR_KIT_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer, nullable: true },
      event_vendor_id: { type: :integer },
      booth_number: { type: :string, example: 'A101' },
      booth_type: { type: :string, example: 'shell_scheme' },
      booth_dimensions: { type: :string, nullable: true, example: '10x10' },
      side_wall_left_required: { type: :boolean, example: false },
      side_wall_right_required: { type: :boolean, example: false },
      name_on_fascia: { type: :string, example: 'Company Name' },
      fascia_upgrade_required: { type: :boolean, example: false },
      company_name: { type: :string, example: 'Exhibitor Co.' },
      company_address: { type: :string, example: '123 Exhibitor St.' },
      country: { type: :string, nullable: true, example: 'Malaysia' },
      pic_full_name: { type: :string, example: 'PIC Name' },
      pic_contact_number: { type: :string, example: '+1234567890' },
      pic_email_address: { type: :string, example: 'pic@example.com' },
      special_requirements: { type: :string, nullable: true, example: 'Extra power outlets' },
      digital_brochure_link: { type: :string, nullable: true, example: 'http://brochure.com' },
      indemnity_signed: { type: :boolean, example: false },
      indemnity_document_url: { type: :string, nullable: true },
      custom_fields_data: { type: :object, nullable: true },
      exhibitor_team_members: { type: :array, items: EXHIBITOR_TEAM_MEMBER_SCHEMA, nullable: true }
    },
    required: %w[event_vendor_id booth_number booth_type name_on_fascia company_name company_address pic_full_name
                 pic_contact_number pic_email_address is_raw_space indemnity_signed]
  }.freeze

  VENDOR_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer },
      event_id: { type: :integer },
      vendor_id: { type: :integer },
      type: { type: :string, enum: %w[Exhibitor Merchant], description: 'Vendor type based on event.use_ticket' },
      redirect_url: { type: :string },
      poster_url: { type: :string, nullable: true },
      qr_url: { type: :string, nullable: true },
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
      exhibitor_kit: {
        type: :object,
        nullable: true,
        description: 'ExhibitorKit object (only present for Exhibitor type)',
        properties: EXHIBITOR_KIT_SCHEMA[:properties]
      }
    },
    required: %w[id event_id vendor_id type redirect_url]
  }.freeze

  EXHIBITOR_KIT_SCHEMA[:properties].merge!(
    exhibitor_booth_price_id: { type: :integer, nullable: true },
    exhibitor_booth_price_label: { type: :string, nullable: true, example: 'Shell Scheme Booth (3m x 3m)' },
    exhibitor_booth_price_conferences_included: { type: :boolean, nullable: true, example: true }
  )

  # ============================================================
  # Setup
  # ============================================================
  let(:org_owner) { create(:user, :org_owner) }
  let(:event_admin_user) { create(:user, :member) }
  let(:non_admin_user) { create(:user, :member) }
  let(:vendor_user) { create(:user, :member) }

  # use the real encoder to generate valid tokens
  let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
  let(:auth_header_non_admin) { "Bearer #{JwtService.generate_tokens(non_admin_user)[:access_token]}" }
  let(:auth_header_org_owner) { "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" }

  # ============================================================
  # GET /v1/events/{event_id}/vendors
  # ============================================================
  path '/v1/events/{event_id}/vendors' do
    let!(:event) { create(:event, title: 'Tech Conference 2024') }
    let!(:event_admin_assignment) do
      create(:event_assignment, event: event, user: event_admin_user, role: 'event_admin')
    end
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'ID of the parent event'

    get 'Lists all vendors assigned to an event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
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

      response '200', 'Returns exhibitor booth price summary inside exhibitor_kit' do
        let!(:event) { create(:event, title: 'Exhibition Event', use_exhibitor_kit: true) }
        let!(:event_admin_assignment) do
          create(:event_assignment, event: event, user: event_admin_user, role: 'event_admin')
        end
        let!(:booth_price) do
          create(
            :exhibitor_booth_price,
            event: event,
            booth_type: 'shell_scheme',
            label: 'Shell Scheme Booth (3m x 3m)',
            conferences_included: true
          )
        end
        let!(:exhibitor_user) { create(:user, role: :vendor, full_name: 'Expo Vendor', email: 'expo@example.com') }
        let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) }

        before do
          exhibitor.exhibitor_kit.update!(exhibitor_booth_price: booth_price)
        end

        schema type: :array,
               items: VENDOR_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          exhibitor_payload = data.find { |vendor| vendor['id'] == exhibitor.id }

          expect(exhibitor_payload).to be_present
          expect(exhibitor_payload['exhibitor_kit']['exhibitor_booth_price_id']).to eq(booth_price.id)
          expect(exhibitor_payload['exhibitor_kit']['exhibitor_booth_price_label']).to eq('Shell Scheme Booth (3m x 3m)')
          expect(exhibitor_payload['exhibitor_kit']).not_to have_key('exhibitor_booth_price_conferences_included')
        end
      end

      response '404', 'Event not found' do
        let(:Authorization) { auth_header_event_admin }
        let(:event_id) { 99_999 }
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
              exhibitor_kit_attributes: {
                type: :object,
                properties: {
                  booth_number: { type: :string, example: 'A101' },
                  booth_type: { type: :string, example: 'shell_scheme' },
                  name_on_fascia: { type: :string, example: 'Company Name' },
                  company_name: { type: :string, example: 'Exhibitor Co.' },
                  company_address: { type: :string, example: '123 Exhibitor St.' },
                  pic_full_name: { type: :string, example: 'PIC Name' },
                  pic_contact_number: { type: :string, example: '+1234567890' },
                  pic_email_address: { type: :string, example: 'pic@example.com' },
                  exhibitor_team_members_attributes: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        full_name: { type: :string, example: 'Team Member 1' }
                      }
                    }
                  }
                },
                required: %w[booth_number booth_type name_on_fascia company_name company_address pic_full_name
                             pic_contact_number pic_email_address]
              }
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
        let(:event_admin_user) { create(:user, :organizer) }
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
        let!(:existing_vendor) do
          create(:user, role: :vendor, email: 'existing_vendor@example.com', full_name: 'Existing Vendor')
        end
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
        let(:event_admin_user) { create(:user, :organizer) }
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
        let!(:existing_user) { create(:user, :member, email: 'existing@example.com', full_name: 'Existing User') }
        let(:event_admin_user) { create(:user, :organizer) }
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
        let(:event_admin_user) { create(:user, :organizer) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }
        let!(:existing_user) do
          create(:user, role: :vendor, email: 'vendor_tech_conference_2024_john@eventzflow.com',
                        full_name: 'Existing User')
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
      # Merchant Creation Tests (event.use_ticket = false)
      # ============================================================
      context 'when event.use_ticket is false (Merchant)' do
        let!(:event) { create(:event, title: 'Merchant Event', use_ticket: false) }
        let(:event_admin_user) { create(:user, :organizer) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }

        response '201', 'Merchant created successfully' do
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
            expect(data['vendor']['email']).to eq('merchant@example.com')
          end
        end
      end

      # ============================================================
      # Exhibitor Creation Tests (event.use_ticket = true)
      # ============================================================
      context 'when event.use_ticket is true (Exhibitor)' do
        let!(:event) { create(:event, title: 'Exhibition Event', use_exhibitor_kit: true) }
        let(:event_admin_user) { create(:user, :organizer) }
        let(:auth_header_event_admin) { "Bearer #{JwtService.generate_tokens(event_admin_user)[:access_token]}" }

        response '201', 'Exhibitor created successfully with nested exhibitor_kit_attributes' do
          let(:body) do
            {
              vendor: {
                full_name: 'Exhibitor with Kit',
                email: 'exhibitorkit@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://exhibitorkit.com',
                exhibitor_kit_attributes: {
                  booth_number: 'B202',
                  booth_type: 'raw_space',
                  name_on_fascia: 'Kit Co.',
                  company_name: 'Kit Exhibitors',
                  company_address: '456 Kit St.',
                  pic_full_name: 'Kit PIC',
                  qr_url: 'https://exhibitorkit.com',
                  pic_contact_number: '+1987654321',
                  pic_email_address: 'kitpic@example.com',
                  exhibitor_team_members_attributes: [
                    { full_name: 'Team Member Alpha', email: 'alpha@example.com', phone: '+60111111111' },
                    { full_name: 'Team Member Beta', email: 'beta@example.com', phone: '+60222222222' }
                  ]
                }
              }
            }
          end

          schema VENDOR_RESPONSE_SCHEMA

          run_test! do |response|
            data = JSON.parse(response.body)

            expect(data['type']).to eq('Exhibitor')
            expect(data['vendor']['email']).to eq('exhibitorkit@example.com')
            expect(data['exhibitor_kit']).to be_present
            expect(data['exhibitor_kit']['booth_number']).to eq('B202')
            expect(data['exhibitor_kit']['exhibitor_team_members'].count).to eq(2)
          end
        end

        response '422', 'Exhibitor creation fails with invalid exhibitor_kit_attributes' do
          let(:body) do
            {
              vendor: {
                full_name: 'Invalid Exhibitor',
                email: 'invalidkit@example.com',
                password: 'securepassword123',
                password_confirmation: 'securepassword123',
                redirect_url: 'https://invalidkit.com',
                exhibitor_kit_attributes: {
                  booth_number: 'C303',
                  booth_type: 'shell_scheme',
                  name_on_fascia: 'Too long name for fascia that should cause validation error', # Too long
                  company_name: 'Invalid Kit Exhibitors',
                  company_address: '789 Invalid St.',
                  pic_full_name: 'Invalid PIC',
                  pic_contact_number: '+1123123123',
                  pic_email_address: 'invalidpic@example.com'
                }
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
            expect(data['errors']).to include('Exhibitor kit name on fascia is too long (maximum is 30 characters)')
          end
        end
      end
    end
  end

  # ============================================================
  # PATCH /v1/events/{event_id}/vendors/{id}
  # ============================================================
  path '/v1/events/{event_id}/vendors/{id}' do
    let!(:event) { create(:event, title: 'Tech Conference 2024') }
    let!(:event_admin_assignment) do
      create(:event_assignment, event: event, user: event_admin_user, role: 'event_admin')
    end
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: :id, in: :path, type: :integer, required: true, description: 'Vendor Assignment ID'

    patch 'Updates an existing vendor for an event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          vendor: {
            type: :object,
            properties: {
              redirect_url: { type: :string, example: 'https://updated.com',
                              description: 'Updated redirect URL for vendor' },
              poster_url: { type: :string, nullable: true },
              qr_url: { type: :string, nullable: true },
              exhibitor_kit_attributes: {
                type: :object,
                properties: {
                  id: { type: :integer, description: 'ID of existing exhibitor kit' },
                  booth_number: { type: :string, example: 'D404' },
                  booth_type: { type: :string, example: 'raw_space' },
                  name_on_fascia: { type: :string, example: 'Updated Name' },
                  exhibitor_team_members_attributes: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        id: { type: :integer, nullable: true },
                        full_name: { type: :string, example: 'Updated Team Member' },
                        _destroy: { type: :boolean, example: false }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        required: ['vendor']
      }

      let(:event_id) { event.id }
      let(:Authorization) { auth_header_event_admin }

      context 'when updating a Merchant' do
        let!(:event_vendor) do
          vendor_user = create(:user, :vendor)
          create(:merchant, event: event, vendor: vendor_user, redirect_url: 'https://original.com')
        end
        let!(:id) { event_vendor.id }

        response '200', 'Merchant updated successfully' do
          let(:body) do
            {
              vendor: {
                redirect_url: 'https://new-merchant.com'
              }
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['redirect_url']).to eq('https://new-merchant.com')
            expect(data['type']).to eq('Merchant')
          end
        end

        response '403', 'Forbidden for non-event-admin or non-owner' do
          let(:Authorization) { auth_header_non_admin }
          let(:body) { { vendor: { redirect_url: 'https://unauthorized.com' } } }

          schema type: :object,
                 properties: {
                   success: { type: :boolean },
                   message: { type: :string }
                 }

          run_test!
        end
      end

      context 'when updating an Exhibitor' do
        # This will be the specific event for this context
        let!(:event) do
          create(:event, title: 'Exhibition Event, for patch', use_exhibitor_kit: true)
        end
        let(:event_id) { event.id } # Override event_id for this context
        let!(:event_admin_assignment) do # New assignment for this event
          create(:event_assignment, event: event, user: event_admin_user, role: 'event_admin')
        end
        let(:exhibitor_user) { create(:user, :vendor) }
        let!(:service_result) do
          EventVendorService.create(
            event: event,
            current_user: event_admin_user, # or another user with permissions
            params: {
              vendor_id: exhibitor_user.id,
              redirect_url: 'https://original-exhibitor.com',
              exhibitor_kit_attributes: {
                booth_number: 'X100',
                booth_type: 'shell_scheme',
                name_on_fascia: 'Old Name',
                company_name: 'Original Company',
                company_address: '123 Test St',
                pic_full_name: 'Original PIC',
                pic_contact_number: '1234567890',
                pic_email_address: 'pic@example.com'
              }
            }
          )
        end
        let!(:existing_exhibitor) do
          EventVendor.exhibitors.includes(:exhibitor_kit,
                                          exhibitor_kit: [:exhibitor_team_members]).find(service_result.data.id)
        end
        let!(:existing_exhibitor_kit) { existing_exhibitor.exhibitor_kit }
        before do
          existing_exhibitor_kit.update!(custom_fields_data: {
                                           'booth_setup_time' => '9:00 AM',
                                           'requires_extra_power' => true
                                         })
        end
        let!(:team_member) do
          create(:exhibitor_team_member, exhibitor_kit: existing_exhibitor_kit, full_name: 'Original Member')
        end
        let!(:id) { existing_exhibitor.id }
        # Use this for exhibitor's own actions
        let(:auth_header_for_exhibitor_user) do
          "Bearer #{JwtService.generate_tokens(exhibitor_user)[:access_token]}"
        end
        response '200', 'Exhibitor and exhibitor_kit updated successfully' do
          let(:body) do
            {
              vendor: {
                redirect_url: 'https://new-exhibitor.com',
                exhibitor_kit_attributes: {
                  id: existing_exhibitor_kit.id,
                  booth_number: 'X101',
                  name_on_fascia: 'New Name for Fascia',
                  exhibitor_team_members_attributes: [
                    { id: team_member.id, full_name: 'Updated Member', email: 'updated.member@example.com',
                      phone: '+60123450000' },
                    { full_name: 'New Member', email: 'new.member@example.com', phone: '+60123459999' }
                  ]
                }
              }
            }
          end

          it 'returns a 200 response' do
            patch "/v1/events/#{event_id}/vendors/#{id}", params: body,
                                                          headers: { 'Authorization' => auth_header_event_admin }
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data['redirect_url']).to eq('https://new-exhibitor.com')
            expect(data['exhibitor_kit']['booth_number']).to eq('X101')
            expect(data['exhibitor_kit']['name_on_fascia']).to eq('New Name for Fascia')
            expect(data['exhibitor_kit']['exhibitor_team_members'].count).to eq(2)
            expect(data['exhibitor_kit']['custom_fields_data']).to eq(
              {
                'booth_setup_time' => '9:00 AM',
                'requires_extra_power' => true
              }
            )
            # expect(data['exhibitor_kit']['exhibitor_team_members'].first['full_name']).to eq('Updated Member')
            # expect(data['exhibitor_kit']['exhibitor_team_members'].last['full_name']).to eq('New Member')
          end
        end

        response '200', 'Exhibitor updates their own redirect_url and exhibitor_kit' do
          let(:body) do
            {
              vendor: {
                redirect_url: 'https://exhibitor-updates-own.com',
                exhibitor_kit_attributes: {
                  id: existing_exhibitor_kit.id,
                  name_on_fascia: 'Exhibitor Own Update'
                }
              }
            }
          end

          it 'returns a 200 response' do
            patch "/v1/events/#{event_id}/vendors/#{id}", params: body,
                                                          headers: { 'Authorization' => auth_header_for_exhibitor_user }
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data['redirect_url']).to eq('https://exhibitor-updates-own.com')
            expect(data['exhibitor_kit']['name_on_fascia']).to eq('Exhibitor Own Update')
          end
        end

        response '200', 'Exhibitor can remove team members' do
          let(:body) do
            {
              vendor: {
                exhibitor_kit_attributes: {
                  id: existing_exhibitor_kit.id,
                  exhibitor_team_members_attributes: [
                    { id: team_member.id, _destroy: true }
                  ]
                }
              }
            }
          end

          it 'returns a 200 response' do
            patch "/v1/events/#{event_id}/vendors/#{id}", params: body,
                                                          headers: { 'Authorization' => auth_header_for_exhibitor_user }
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data['exhibitor_kit']['exhibitor_team_members']).to be_empty
          end
        end

        response '403', 'Forbidden for non-event-admin or non-owner' do
          let(:body) do
            {
              vendor: {
                redirect_url: 'https://unauthorized.com'
              }
            }
          end

          it 'returns a 403 response' do
            patch "/v1/events/#{event_id}/vendors/#{id}", params: body,
                                                          headers: { 'Authorization' => auth_header_non_admin }
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end
end
