# visitor_imports_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Imports - Visitors', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user, :member) }
  let(:staff_user) { create(:user, :staff_member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event ---
  let!(:organizer_event) do
    event = create(:event, title: 'Visitor Import Test Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  # =========================================================================
  # VISITOR IMPORT ENDPOINTS
  # =========================================================================

  path '/v1/imports/visitors' do
    post 'Import visitors from Excel file' do
      tags 'Imports'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :dry_run, in: :query, type: :boolean, required: false,
                description: 'If true, validate and report without writing changes'
      parameter name: :full, in: :query, type: :boolean, required: false,
                description: 'If true, include full record data in response'
      parameter name: :no_label, in: :query, type: :boolean, required: false,
                description: 'When true, use sequential Label N keys; when false, use header names as keys'
      parameter name: :file, in: :formData, type: :file, required: true,
                description: 'Excel file (.xlsx) with visitor data'

      response '200', 'Visitors imported successfully' do
        schema type: :object,
               properties: {
                 success: { type: :boolean },
                 message: { type: :string },
                 data: {
                   type: :object,
                   properties: {
                     total: { type: :integer },
                     created: { type: :object },
                     updated: { type: :object },
                     skipped: { type: :object },
                     duplicates_in_file: { type: :object },
                     errors: { type: :object }
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
          workbook.add_worksheet(name: "Visitors") do |sheet|
            sheet.add_row ['Full Name', 'Email', 'Phone', 'Gender', 'Age', 'Role', 'Event Title', 'Company']
            sheet.add_row ['Test Visitor', 'visitor@example.com', '+1234567890', 'male', 30, 'Visitor', organizer_event.title, 'Acme Inc']
          end

          temp_file = Tempfile.new(['test_visitor_import', '.xlsx'])
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
          # Dry-run should not persist
          count_before = Visitor.where(email: 'visitor@example.com').count
          expect(count_before).to eq(0)
        end
      end

      response '401', 'Unauthorized - Missing or invalid token' do
        schema type: :object, properties: { error: { type: :string } }

        let(:Authorization) { nil }
        let(:file) { Rack::Test::UploadedFile.new(__FILE__, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

        run_test!
      end

      response '422', 'Unprocessable Entity - No file provided' do
        schema type: :object, properties: { error: { type: :string } }

        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:file) { nil }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['error']).to eq('No file provided')
        end
      end
    end
  end

  # =========================================================================
  # VISITOR IMPORT BEHAVIOR TESTS
  # =========================================================================

  describe 'Visitor import behavior' do
    let(:auth_header) { "Bearer #{organizer_token}" }

    def build_visitor_excel(rows, custom_columns: [])
      require 'caxlsx'
      package = Axlsx::Package.new
      workbook = package.workbook
      workbook.add_worksheet(name: "Visitors") do |sheet|
        header_row = ['Full Name', 'Email', 'Phone', 'Gender', 'Age', 'Role', 'Event Title']
        header_row.concat(custom_columns)
        sheet.add_row header_row
        # Adjust rows to include nil/empty Role if not provided (assuming rows passed don't have it yet, need to check usages)
        # Actually, let's just insert a default Role 'Visitor' into the rows before writing
        rows.each do |r| 
          # r is [Name, Email, Phone, Gender, Age, EventTitle]
          # We need [Name, Email, Phone, Gender, Age, Role, EventTitle]
          # Insert Role at index 5
          new_row = r.dup
          new_row.insert(5, 'Visitor')
          sheet.add_row new_row
        end
      end
      tmp = Tempfile.new(['import_visitors', '.xlsx'])
      package.serialize(tmp.path)
      tmp.rewind
      Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'creates visitors with all fields' do
      file = build_visitor_excel([
        ['Complete Visitor', 'complete@example.com', '+1234567890', 'female', 28, organizer_event.title]
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['created']['count']).to eq(1)

      visitor = organizer_event.visitors.find_by(full_name: 'Complete Visitor')
      expect(visitor).to be_present
      expect(visitor.email).to eq('complete@example.com')
      expect(visitor.gender).to eq('female')
      expect(visitor.age).to eq(28)
    end

    it 'allows same email when names differ' do
      file = build_visitor_excel([
        ['Alice Smith', 'shared@company.com', '', 'female', 30, organizer_event.title],
        ['Bob Smith', 'shared@company.com', '', 'male', 32, organizer_event.title]
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['created']['count']).to eq(2)
    end

    it 'normalizes names for duplicate detection' do
      file = build_visitor_excel([
        ['John Doe', 'john1@example.com', '', 'male', 30, organizer_event.title],
        ['JOHN DOE', 'john2@example.com', '', 'male', 30, organizer_event.title],
        ['john  doe', 'john3@example.com', '', 'male', 30, organizer_event.title]
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      # All three should be treated as the same person
      expect(json['data']['created']['count']).to eq(1)
      expect(json['data']['duplicates_in_file']['count']).to eq(2)
    end

    it 'updates existing visitors when more complete' do
      # Create existing visitor with minimal data
      organizer_event.visitors.create!(full_name: 'Existing Visitor', email: nil, phone: nil)

      file = build_visitor_excel([
        ['Existing Visitor', 'updated@example.com', '+1111111111', 'male', 35, organizer_event.title]
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['updated']['count']).to eq(1)

      visitor = organizer_event.visitors.find_by(full_name: 'Existing Visitor')
      expect(visitor.email).to eq('updated@example.com')
      expect(visitor.phone).to eq('1111111111')
    end

    it 'skips rows with missing required fields' do
      file = build_visitor_excel([
        ['', 'nofullname@example.com', '', 'male', 30, organizer_event.title],  # Missing full_name
        ['No Event Title', 'noevent@example.com', '', 'female', 25, '']         # Missing event_title
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['created']['count']).to eq(0)
      expect(json['data']['skipped']['count']).to eq(2)
    end

    it 'creates custom fields with header keys when no_label=false' do
      file = build_visitor_excel(
        [['Header Key Visitor', 'header@example.com', '', 'male', 25, organizer_event.title, 'Tech Corp']],
        custom_columns: ['Company']
      )

      post '/v1/imports/visitors', params: { file: file, dry_run: false, no_label: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload

      expect(organizer_event.labels_data['company']).to eq('Company')

      visitor = organizer_event.visitors.find_by(full_name: 'Header Key Visitor')
      expect(visitor.custom_fields_data['company']).to eq('Tech Corp')
    end

    it 'creates custom fields with Label N keys when no_label=true' do
      file = build_visitor_excel(
        [['Label N Visitor', 'labeln@example.com', '', 'male', 25, organizer_event.title, 'Tech Corp']],
        custom_columns: ['Company']
      )

      post '/v1/imports/visitors', params: { file: file, dry_run: false, no_label: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      organizer_event.reload

      expect(organizer_event.labels_data['Label 1']).to eq('Company')

      visitor = organizer_event.visitors.find_by(full_name: 'Label N Visitor')
      expect(visitor.custom_fields_data['Label 1']).to eq('Tech Corp')
    end

    it 'updates custom_fields_data on existing visitors' do
      organizer_event.update!(labels_data: { 'company' => 'Company' })
      organizer_event.visitors.create!(full_name: 'Custom Update Visitor', custom_fields_data: { 'company' => 'Old Company' })

      file = build_visitor_excel(
        [['Custom Update Visitor', '', '', '', '', organizer_event.title, 'New Company']],
        custom_columns: ['Company']
      )

      post '/v1/imports/visitors', params: { file: file, dry_run: false, no_label: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['updated']['count']).to eq(1)

      visitor = organizer_event.visitors.find_by(full_name: 'Custom Update Visitor')
      expect(visitor.custom_fields_data['company']).to eq('New Company')
    end

    it 'does not persist changes when dry_run=true' do
      file = build_visitor_excel([
        ['Dry Run Visitor', 'dryrun@example.com', '', 'male', 30, organizer_event.title]
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: true }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['created']['count']).to eq(1)

      # Should not be persisted
      visitor = Visitor.find_by(email: 'dryrun@example.com')
      expect(visitor).to be_nil
    end

    it 'creates new event if event_title does not exist' do
      file = build_visitor_excel([
        ['New Event Visitor', 'newevent@example.com', '', 'female', 25, 'Brand New Event']
      ])

      post '/v1/imports/visitors', params: { file: file, dry_run: false }, headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['created']['count']).to eq(1)

      new_event = Event.find_by(title: 'Brand New Event')
      expect(new_event).to be_present
      expect(new_event.visitors.count).to eq(1)
    end
  end
end
