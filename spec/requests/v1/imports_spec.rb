# imports_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Imports', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }
  let(:staff_user) { create(:staff_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:manager_token) { JwtService.generate_tokens(manager_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event (Controlled by Manager) ---
  let!(:manager_event) do
    event = create(:event, title: 'Import Test Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: manager_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  # =========================================================================
  # IMPORT ENDPOINTS
  # =========================================================================

  path '/v1/imports/tickets' do
    post 'Import tickets from Excel file' do
      tags 'Imports'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :dry_run, in: :query, type: :boolean, required: false,
                description: 'If true, validate and report without writing changes'
      parameter name: :full, in: :query, type: :boolean, required: false,
                description: 'If true, use full import mode with additional validation and processing'
      parameter name: :file, in: :formData, type: :file, required: true,
                description: 'Excel file (.xlsx) with ticket data'

      response '200', 'Tickets imported successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     total: { type: :integer, description: 'Total number of tickets processed' },
                     created: {
                       type: :object,
                       properties: {
                         count: { type: :integer, description: 'Number of tickets created' },
                         data: { type: :array, items: { type: :object }, description: 'Array of created ticket data' }
                       }
                     },
                     updated: {
                       type: :object,
                       properties: {
                         count: { type: :integer, description: 'Number of tickets updated (more complete rows)' },
                         data: { type: :array, items: { type: :object }, description: 'Array of updated ticket data' }
                       },
                       description: 'Present only when tickets were updated'
                     },
                     skipped: {
                       type: :object,
                       properties: {
                         count: { type: :integer, description: 'Number of tickets skipped (duplicates)' },
                         data: { type: :array, items: { type: :object }, description: 'Array of skipped ticket data' }
                       }
                     },
                     duplicates_in_file: {
                       type: :object,
                       properties: {
                         count: { type: :integer, description: 'Number of duplicate rows collapsed within the file' },
                         data: { type: :array, items: { type: :object }, description: 'Array of duplicate ticket data' }
                       },
                       description: 'Present only when duplicates were found in the file'
                     },
                     errors: {
                       type: :object,
                       properties: {
                         count: { type: :integer, description: 'Number of errors encountered' },
                         data: { type: :array, items: { type: :string }, description: 'Array of error messages' }
                       }
                     }
                   },
                   required: [:total, :created, :skipped, :errors]
                 }
               }

        let(:Authorization) { "Bearer #{manager_token}" }
        let(:dry_run) { true }
        let(:file) do
          # Create a test Excel file
          require 'caxlsx'
          package = Axlsx::Package.new
          workbook = package.workbook
          workbook.add_worksheet(name: "Tickets") do |sheet|
            sheet.add_row ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In', 'Role']
            sheet.add_row ['Test Import User', 'import.test@example.com', '+1234567890', 'Import Test Event', 'GA', '', '', 'pending', 'false', 'Delegate']
          end

          temp_file = Tempfile.new(['test_import', '.xlsx'])
          package.serialize(temp_file.path)
          temp_file.rewind

          Rack::Test::UploadedFile.new(temp_file.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']['total']).to be >= 0
          expect(json['data']['created']).to be_a(Hash)
          expect(json['data']['created']['count']).to be >= 0
          expect(json['data']['created']['data']).to be_an(Array)
          expect(json['data']['skipped']).to be_a(Hash)
          expect(json['data']['skipped']['count']).to be >= 0
          expect(json['data']['errors']).to be_a(Hash)
          expect(json['data']['errors']['count']).to be >= 0
          expect(json['data']['errors']['data']).to be_an(Array)
          # Dry-run should not persist
          count_before = Ticket.where(attendee_email: 'import.test@example.com').count
          expect(count_before).to eq(0)
        end
      end

      response '200', 'Allows same phone/email when names differ (business rule)' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     total: { type: :integer },
                     created: {
                       type: :object,
                       properties: {
                         count: { type: :integer },
                         data: { type: :array, items: { type: :object } }
                       }
                     },
                     updated: {
                       type: :object,
                       properties: {
                         count: { type: :integer },
                         data: { type: :array, items: { type: :object } }
                       }
                     },
                     skipped: {
                       type: :object,
                       properties: {
                         count: { type: :integer },
                         data: { type: :array, items: { type: :object } }
                       }
                     },
                     duplicates_in_file: {
                       type: :object,
                       properties: {
                         count: { type: :integer },
                         data: { type: :array, items: { type: :object } }
                       }
                     },
                     errors: {
                       type: :object,
                       properties: {
                         count: { type: :integer },
                         data: { type: :array, items: { type: :string } }
                       }
                     }
                   },
                   required: [:total, :created, :skipped, :errors]
                 }
               }

        let(:Authorization) { "Bearer #{manager_token}" }
        let(:dry_run) { true }
        let(:file) do
          require 'caxlsx'
          package = Axlsx::Package.new
          workbook = package.workbook
          workbook.add_worksheet(name: "Tickets") do |sheet|
            sheet.add_row ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In']
            # Two rows: same phone/email, different names, same event+type
            sheet.add_row ['Alice Example', 'shared@company.com', '0168100005', manager_event.title, 'GA', '', '', 'pending', 'false']
            sheet.add_row ['Bob Example',   'shared@company.com', '0168100005', manager_event.title, 'GA', '', '', 'pending', 'false']
          end

          temp_file = Tempfile.new(['test_import_dupes', '.xlsx'])
          package.serialize(temp_file.path)
          temp_file.rewind

          Rack::Test::UploadedFile.new(temp_file.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']['total']).to be >= 0
          expect(json['data']['created']).to be_a(Hash)
          # Both should be considered distinct (names differ), so created >= 2 on live; in dry_run, we still see would-create 2
          expect(json['data']['created']['count']).to be >= 2
          expect(json['data']['created']['data']).to be_an(Array)
        end
      end

      response '401', 'Unauthorized - Missing or invalid token' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { nil }
        let(:file) { Rack::Test::UploadedFile.new(__FILE__, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

        run_test!
      end

      response '422', 'Unprocessable Entity - No file provided or import failed' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 errors: { type: :array, items: { type: :string } }
               }

        let(:Authorization) { "Bearer #{manager_token}" }
        let(:file) { nil }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['error']).to eq('No file provided')
        end
      end
    end
  end
end
