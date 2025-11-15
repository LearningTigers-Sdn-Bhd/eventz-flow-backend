# imports_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Imports', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:org_owner) }
  let(:organizer_user) { create(:organizer_user) }
  let(:member_user) { create(:member_user) }
  let(:staff_user) { create(:staff_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event (Controlled by Organizer) ---
  let!(:organizer_event) do
    event = create(:event, title: 'Import Test Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
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
      parameter name: :no_label, in: :query, type: :boolean, required: false,
                description: 'When true, use sequential Label N keys; when false, use header names as keys'
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
                         count: { type: :integer, description: 'Number of tickets updated (more complete rows or data changes)' },
                         data: {
                           type: :array,
                           items: {
                             type: :object,
                             properties: {
                               model: { type: :string },
                               id: { type: :string },
                               changed_fields: {
                                 type: :array,
                                 items: { type: :string },
                                 description: 'Array of field names that changed (e.g., ["payment_status", "custom_fields_data"])'
                               }
                             }
                           },
                           description: 'Array of updated ticket data with changed_fields tracking'
                         }
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

        let(:Authorization) { "Bearer #{organizer_token}" }
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

      response '200', 'Preserves empty label values in custom_fields_data (header/machine key style)' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: { type: :object }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:dry_run) { true }
        let(:no_label) { false }
        let(:file) do
          require 'caxlsx'
          package = Axlsx::Package.new
          workbook = package.workbook
          workbook.add_worksheet(name: 'Tickets') do |sheet|
            sheet.add_row ['Attendee Name','Attendee Email','Attendee Phone','Event Title','Ticket Type','Public ID','QR Code','Payment Status','Checked In','Role']
            # Empty Role cell
            sheet.add_row ['Empty Role User','emptyrole@example.com','+1000000000', organizer_event.title, 'GA', '', '', 'pending', 'false', '']
          end
          tmp = Tempfile.new(['import_empty_role', '.xlsx'])
          package.serialize(tmp.path)
          tmp.rewind
          Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          created = json.dig('data', 'created', 'data') || []
          expect(created).to be_an(Array)
          first = created.find { |r| r['attendee_email'] == 'emptyrole@example.com' }
          expect(first).to be_present
          # In header style, key should be machine key 'role' with empty string value
          expect(first).to include('role' => '')
        end
      end

      response '200', 'Preserves empty label values in custom_fields_data (Label N style)' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: { type: :object }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:dry_run) { true }
        let(:no_label) { true }
        let(:file) do
          require 'caxlsx'
          package = Axlsx::Package.new
          workbook = package.workbook
          workbook.add_worksheet(name: 'Tickets') do |sheet|
            sheet.add_row ['Attendee Name','Attendee Email','Attendee Phone','Event Title','Ticket Type','Public ID','QR Code','Payment Status','Checked In','Role']
            # Empty Role cell
            sheet.add_row ['Empty LabelN User','emptylabeln@example.com','+1000000001', organizer_event.title, 'GA', '', '', 'pending', 'false', '']
          end
          tmp = Tempfile.new(['import_empty_labeln', '.xlsx'])
          package.serialize(tmp.path)
          tmp.rewind
          Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          created = json.dig('data', 'created', 'data') || []
          expect(created).to be_an(Array)
          first = created.find { |r| r['attendee_email'] == 'emptylabeln@example.com' }
          expect(first).to be_present
          # In Label N style, key should be 'Label 1' with empty string value (first custom column)
          expect(first).to include('Label 1' => '')
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

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:dry_run) { true }
        let(:file) do
          require 'caxlsx'
          package = Axlsx::Package.new
          workbook = package.workbook
          workbook.add_worksheet(name: "Tickets") do |sheet|
            sheet.add_row ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In']
            # Two rows: same phone/email, different names, same event+type
            sheet.add_row ['Alice Example', 'shared@company.com', '0168100005', organizer_event.title, 'GA', '', '', 'pending', 'false']
            sheet.add_row ['Bob Example',   'shared@company.com', '0168100005', organizer_event.title, 'GA', '', '', 'pending', 'false']
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

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:file) { nil }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['error']).to eq('No file provided')
        end
      end
    end
  end

  # Additional behavior tests for custom labels merging
  describe 'Custom labels merging behavior' do
    let(:auth_header) { "Bearer #{organizer_token}" }

    def build_excel_with_custom_columns(rows, custom_columns: [])
      require 'caxlsx'
      package = Axlsx::Package.new
      workbook = package.workbook
      workbook.add_worksheet(name: "Tickets") do |sheet|
        header_row = ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In']
        header_row.concat(custom_columns)
        sheet.add_row header_row
        rows.each { |r| sheet.add_row r }
      end
      tmp = Tempfile.new(['import_labels', '.xlsx'])
      package.serialize(tmp.path)
      tmp.rewind
      Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'merges new labels with existing labels_data' do
      # Set up event with existing labels
      existing_labels = { 'Label 1' => 'Role', 'Label 2' => 'Company' }
      organizer_event.update!(labels_data: existing_labels)

      # Import with new custom column
      file = build_excel_with_custom_columns(
        [['Test User', 'test@example.com', '', organizer_event.title, 'GA', '', '', 'pending', 'false', 'Manager']],
        custom_columns: ['Department']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload

      # Verify existing labels are preserved
      expect(organizer_event.labels_data['Label 1']).to eq('Role')
      expect(organizer_event.labels_data['Label 2']).to eq('Company')

      # Verify new label is added
      expect(organizer_event.labels_data['Label 3']).to eq('Department')
    end

    it 'preserves all existing labels when importing new ones' do
      # Set up event with multiple existing labels
      existing_labels = { 'Label 1' => 'Role', 'Label 2' => 'Company', 'Label 3' => 'Dietary Restrictions' }
      organizer_event.update!(labels_data: existing_labels)

      # Import with one new custom column
      file = build_excel_with_custom_columns(
        [['Test User 2', 'test2@example.com', '', organizer_event.title, 'GA', '', '', 'pending', 'false']],
        custom_columns: ['T-Shirt Size']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload

      # Verify all existing labels are preserved
      expect(organizer_event.labels_data['Label 1']).to eq('Role')
      expect(organizer_event.labels_data['Label 2']).to eq('Company')
      expect(organizer_event.labels_data['Label 3']).to eq('Dietary Restrictions')

      # Verify new label is added
      expect(organizer_event.labels_data['Label 4']).to eq('T-Shirt Size')
      expect(organizer_event.labels_data.keys.length).to eq(4)
    end

    it 'creates labels_data for new events when importing custom columns' do
      # Event without existing labels
      new_event = create(:event, title: 'New Event', labels_data: nil)
      EventAssignment.find_or_create_by!(event: new_event, user: organizer_user, role: :event_admin)

      file = build_excel_with_custom_columns(
        [['New Event User', 'new@example.com', '', new_event.title, 'GA', '', '', 'pending', 'false', 'VIP']],
        custom_columns: ['VIP Level']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      new_event.reload

      # Verify labels_data is created
      expect(new_event.labels_data).to be_present
      expect(new_event.labels_data['Label 1']).to eq('VIP Level')
    end

    it 'updates existing label display name when importing with changed column header' do
      # Set up event with existing label
      existing_labels = { 'Label 1' => 'Role' }
      organizer_event.update!(labels_data: existing_labels)

      # Import with new column header (e.g., "Position" instead of "Role")
      file = build_excel_with_custom_columns(
        [['Update Test User', 'update@example.com', '', organizer_event.title, 'GA', '', '', 'pending', 'false', 'Manager']],
        custom_columns: ['Position']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload

      # Verify the existing label is preserved and new label is added
      expect(organizer_event.labels_data['Label 1']).to eq('Role')
      expect(organizer_event.labels_data['Label 2']).to eq('Position')
    end

    it 'updates existing label display name when importing with same column header' do
      # Set up event with existing label "Old Role Name"
      existing_labels = { 'Label 1' => 'Old Role Name' }
      organizer_event.update!(labels_data: existing_labels)

      # Import with same column header "Role" (replaces existing Label 1 value)
      file = build_excel_with_custom_columns(
        [['Update Test User 2', 'update2@example.com', '', organizer_event.title, 'GA', '', '', 'pending', 'false']],
        custom_columns: ['Role']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload

      # Verify the label display name was updated (same key "Label 1", different value)
      expect(organizer_event.labels_data['Label 1']).to eq('Role')
    end

  end

  # Additional behavior tests for payment status upgrades
  describe 'Payment status upgrade behavior' do
    let(:auth_header) { "Bearer #{organizer_token}" }

    def build_excel(rows)
      require 'caxlsx'
      package = Axlsx::Package.new
      workbook = package.workbook
      workbook.add_worksheet(name: "Tickets") do |sheet|
        sheet.add_row ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In']
        rows.each { |r| sheet.add_row r }
      end
      tmp = Tempfile.new(['import_paid', '.xlsx'])
      package.serialize(tmp.path)
      tmp.rewind
      Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    def build_excel_with_custom_columns(rows, custom_columns: [])
      require 'caxlsx'
      package = Axlsx::Package.new
      workbook = package.workbook
      workbook.add_worksheet(name: "Tickets") do |sheet|
        header_row = ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In']
        header_row.concat(custom_columns)
        sheet.add_row header_row
        rows.each { |r| sheet.add_row r }
      end
      tmp = Tempfile.new(['import_labels', '.xlsx'])
      package.serialize(tmp.path)
      tmp.rewind
      Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'upgrades to paid even when row is not more complete' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      ticket = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'Paid Upgrade User', attendee_email: '', attendee_phone: '', status: :purchased, payment_status: :pending, checked_in: false)

      file = build_excel([
        ['Paid Upgrade User', '', '', organizer_event.title, 'GA', '', '', 'paid', 'false']
      ])

      post '/v1/imports/tickets', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      ticket.reload
      expect(ticket.payment_status).to eq('paid')
    end

    it 'does not downgrade from paid' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      ticket = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'No Downgrade User', attendee_email: '', attendee_phone: '', status: :purchased, payment_status: :paid, checked_in: false)

      file = build_excel([
        ['No Downgrade User', '', '', organizer_event.title, 'GA', '', '', 'pending', 'false']
      ])

      post '/v1/imports/tickets', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      ticket.reload
      expect(ticket.payment_status).to eq('paid')
    end

    it 'does not persist upgrade when dry_run=true' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      ticket = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'Dry Run User', attendee_email: '', attendee_phone: '', status: :purchased, payment_status: :pending, checked_in: false)

      file = build_excel([
        ['Dry Run User', '', '', organizer_event.title, 'GA', '', '', 'paid', 'false']
      ])

      post '/v1/imports/tickets', params: { file: file, dry_run: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      ticket.reload
      expect(ticket.payment_status).to eq('pending')
    end

    it 'includes changed_fields when payment_status changes' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      ticket = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'Changed Fields User', attendee_email: '', attendee_phone: '', status: :purchased, payment_status: :pending, checked_in: false)

      file = build_excel([
        ['Changed Fields User', '', '', organizer_event.title, 'GA', '', '', 'paid', 'false']
      ])

      post '/v1/imports/tickets', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['data']['updated']).to be_present
      expect(json['data']['updated']['count']).to eq(1)
      expect(json['data']['updated']['data'].length).to eq(1)

      updated_item = json['data']['updated']['data'].first
      expect(updated_item['model']).to eq('Ticket')
      expect(updated_item['id']).to eq(ticket.id.to_s)
      expect(updated_item['changed_fields']).to be_an(Array)
      expect(updated_item['changed_fields']).to include('payment_status')
    end

    it 'includes changed_fields even when full: false' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      ticket = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'Full False User', attendee_email: '', attendee_phone: '', status: :purchased, payment_status: :pending, checked_in: false)

      file = build_excel([
        ['Full False User', '', '', organizer_event.title, 'GA', '', '', 'paid', 'false']
      ])

      post '/v1/imports/tickets', params: { file: file, dry_run: false, full: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['data']['updated']).to be_present
      expect(json['data']['updated']['count']).to eq(1)

      updated_item = json['data']['updated']['data'].first
      expect(updated_item['model']).to eq('Ticket')
      expect(updated_item['id']).to eq(ticket.id.to_s)
      expect(updated_item['changed_fields']).to be_an(Array)
      expect(updated_item['changed_fields']).to include('payment_status')
      # When full: false, only basic fields should be included
      expect(updated_item['attendee_name']).to be_nil
    end

    it 'includes changed_fields when custom_fields_data changes' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      organizer_event.update!(labels_data: { 'Label 1' => 'Role' })
      ticket = organizer_event.tickets.create!(
        ticket_type: ga,
        attendee_name: 'Custom Labels User',
        attendee_email: '',
        attendee_phone: '',
        status: :purchased,
        payment_status: :pending,
        checked_in: false,
        custom_fields_data: { 'Label 1' => 'Old Role' }
      )

      file = build_excel_with_custom_columns(
        [['Custom Labels User', '', '', organizer_event.title, 'GA', '', '', 'pending', 'false', 'New Role']],
        custom_columns: ['Role']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['data']['updated']).to be_present
      expect(json['data']['updated']['count']).to eq(1)

      updated_item = json['data']['updated']['data'].first
      expect(updated_item['changed_fields']).to be_an(Array)
      expect(updated_item['changed_fields']).to include('custom_fields_data')
    end

    it 'includes changed_fields for both payment_status and custom_fields_data when both change' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      organizer_event.update!(labels_data: { 'Label 1' => 'Role' })
      ticket = organizer_event.tickets.create!(
        ticket_type: ga,
        attendee_name: 'Both Changed User',
        attendee_email: '',
        attendee_phone: '',
        status: :purchased,
        payment_status: :pending,
        checked_in: false,
        custom_fields_data: { 'Label 1' => 'Old Role' }
      )

      file = build_excel_with_custom_columns(
        [['Both Changed User', '', '', organizer_event.title, 'GA', '', '', 'paid', 'false', 'New Role']],
        custom_columns: ['Role']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['data']['updated']).to be_present
      expect(json['data']['updated']['count']).to eq(1)

      updated_item = json['data']['updated']['data'].first
      expect(updated_item['changed_fields']).to be_an(Array)
      expect(updated_item['changed_fields']).to include('payment_status')
      expect(updated_item['changed_fields']).to include('custom_fields_data')
    end
  end

  # Tests for no_label flag behavior and synchronization
  describe 'no_label flag behavior' do
    let(:auth_header) { "Bearer #{organizer_token}" }

    def build_excel_with_custom_columns(rows, custom_columns: [])
      require 'caxlsx'
      package = Axlsx::Package.new
      workbook = package.workbook
      workbook.add_worksheet(name: "Tickets") do |sheet|
        header_row = ['Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title', 'Ticket Type', 'Public ID', 'QR Code', 'Payment Status', 'Checked In']
        header_row.concat(custom_columns)
        sheet.add_row header_row
        rows.each { |r| sheet.add_row r }
      end
      tmp = Tempfile.new(['import_labels_style', '.xlsx'])
      package.serialize(tmp.path)
      tmp.rewind
      Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'uses header machine keys when no_label=false and syncs existing tickets to header keys' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      # Pre-existing ticket with Label N keys should be migrated to header keys
      organizer_event.update!(labels_data: { 'Label 1' => 'Role' })
      t = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'Key Sync User', status: :purchased, payment_status: :pending, checked_in: false, custom_fields_data: { 'Label 1' => 'Speaker' })

      file = build_excel_with_custom_columns(
        [['Key Sync User 2', 'sync2@example.com', '', organizer_event.title, 'GA', '', '', 'pending', 'false', 'VIP']],
        custom_columns: ['Role']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload
      t.reload

      # Event labels_data should use machine key => display name mapping
      expect(organizer_event.labels_data).to include('role' => 'Role')
      # Existing ticket keys should be synchronized to machine keys
      expect(t.custom_fields_data).to include('role' => 'Speaker')
      expect(t.custom_fields_data.keys).not_to include('Label 1')
    end

    it 'uses Label N keys when no_label=true and syncs existing tickets to Label N' do
      ga = organizer_event.ticket_types.create!(name: 'GA', price: 0, quantity: 1000, status: :draft)
      # Pre-existing ticket with header keys should be migrated to Label N keys
      organizer_event.update!(labels_data: { 'role' => 'Role' })
      t = organizer_event.tickets.create!(ticket_type: ga, attendee_name: 'Key Sync User 3', status: :purchased, payment_status: :pending, checked_in: false, custom_fields_data: { 'role' => 'Panelist' })

      file = build_excel_with_custom_columns(
        [['Key Sync User 4', 'sync4@example.com', '', organizer_event.title, 'GA', '', '', 'pending', 'false', 'Delegate']],
        custom_columns: ['Role']
      )

      post '/v1/imports/tickets', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload
      t.reload

      # Event labels_data should use sequential Label N => display name
      # At least Label 1 should be 'Role'
      expect(organizer_event.labels_data['Label 1']).to eq('Role')
      # Existing ticket keys should be synchronized to Label N keys
      expect(t.custom_fields_data).to include('Label 1' => 'Panelist')
      expect(t.custom_fields_data.keys).not_to include('role')
    end
  end
end
