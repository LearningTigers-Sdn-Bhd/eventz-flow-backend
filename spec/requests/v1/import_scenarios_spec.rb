require 'rails_helper'

# End-to-end scenario coverage for the ticket import flow, mirroring the manual
# test files in tmp/import-test-files. Each scenario posts a generated .xlsx and
# asserts the resulting DB state + response contract.
RSpec.describe 'Ticket import scenarios', type: :request do
  let(:organizer_user) { create(:user, :organizer) }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:auth_header) { { 'Authorization' => "Bearer #{organizer_token}" } }

  let!(:organizer_event) do
    event = create(:event, title: 'Existing Scenario Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    event
  end
  let!(:ga_type) { organizer_event.ticket_types.create!(name: 'General Admission', price: 0, quantity: 1000, status: :draft) }

  HEADERS = [
    'Attendee Name', 'Attendee Email', 'Attendee Phone', 'Event Title',
    'Ticket Type', 'Role', 'Public ID', 'QR Code', 'Payment Status',
    'Checked In', 'Created At', 'Review Status'
  ].freeze

  def build_xlsx(rows, custom_columns: [])
    require 'caxlsx'
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: 'Tickets') do |sheet|
      sheet.add_row(HEADERS + custom_columns)
      rows.each { |r| sheet.add_row r }
    end
    tmp = Tempfile.new(['scenario', '.xlsx'])
    package.serialize(tmp.path)
    tmp.rewind
    Rack::Test::UploadedFile.new(tmp.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  end

  # name, email, phone, event, type, role, public_id, qr, payment, checked_in, created_at, review, *custom
  def row(name:, email: '', phone: '', event:, type: 'General Admission', role: 'Delegate',
          payment: 'paid', checked_in: 'false', custom: [])
    [name, email, phone, event, type, role, '', '', payment, checked_in, '', '', *custom]
  end

  def post_import(file, **params)
    post '/v1/imports/tickets', params: { file: file }.merge(params), headers: auth_header
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  it '1. fresh import with good data creates event, tickets, and custom fields' do
    file = build_xlsx([
      row(name: 'Alice Tan', email: 'alice@example.com', event: 'Scenario Fresh A', custom: ['Acme']),
      row(name: 'Bob Lim', email: 'bob@example.com', event: 'Scenario Fresh A', payment: 'pending', custom: ['Beta'])
    ], custom_columns: ['Company'])

    json = post_import(file, dry_run: false)
    expect(json['data']['created']['count']).to eq(2)

    event = Event.find_by(title: 'Scenario Fresh A')
    expect(event).to be_present
    expect(event.tickets.count).to eq(2)
    expect(event.tickets.find_by(attendee_name: 'Alice Tan').custom_fields_data['company']).to eq('Acme')
  end

  it '2. whitespace/case variants of one event name collapse to a single new event' do
    file = build_xlsx([
      row(name: 'Diana Lee', event: 'Sabah Expo 2026'),
      row(name: 'Edward Ng', event: 'sabah expo 2026'),
      row(name: 'Fiona Chen', event: 'Sabah  Expo 2026')
    ])

    json = post_import(file, dry_run: true)
    events = json['data']['events']
    # All three spellings normalize to the same event — one target, not three.
    expect(events.length).to eq(1)
    expect(events.first['exists']).to be false
    expect(events.first['row_count']).to eq(3)
  end

  it '2b. genuinely different event names still create separate events' do
    file = build_xlsx([
      row(name: 'Diana Lee', event: 'Sabah Expo 2026'),
      row(name: 'Edward Ng', event: 'Sabah Expo 2027')
    ])

    json = post_import(file, dry_run: true)
    events = json['data']['events']
    expect(events.length).to eq(2)
    expect(events.map { |e| e['exists'] }).to all(be false)
  end

  it '2c. real import of whitespace/case variants creates one event with all tickets' do
    file = build_xlsx([
      row(name: 'Diana Lee', event: 'Sabah Expo 2026'),
      row(name: 'Edward Ng', event: 'sabah expo 2026'),
      row(name: 'Fiona Chen', event: 'Sabah  Expo 2026')
    ])

    expect do
      json = post_import(file, dry_run: false)
      expect(json['data']['created']['count']).to eq(3)
    end.to change(Event, :count).by(1)

    event = Event.find_by(title: 'Sabah Expo 2026')
    expect(event.tickets.count).to eq(3)
  end

  it '3. import into an existing event reuses it (no new event created)' do
    file = build_xlsx([
      row(name: 'George Ho', event: organizer_event.title, custom: ['Existing Co'])
    ], custom_columns: ['Company'])

    expect do
      json = post_import(file, dry_run: false)
      expect(json['data']['created']['count']).to eq(1)
    end.not_to change(Event, :count)

    expect(organizer_event.tickets.find_by(attendee_name: 'George Ho')).to be_present
  end

  it '4. reimport updates existing tickets (payment upgrade + custom field change)' do
    organizer_event.tickets.create!(ticket_type: ga_type, attendee_name: 'Ivan Kumar', status: :purchased,
                                    payment_status: :pending, custom_fields_data: { 'company' => 'Old Company' })
    organizer_event.update!(labels_data: { 'company' => 'Company' })

    file = build_xlsx([
      row(name: 'Ivan Kumar', event: organizer_event.title, payment: 'paid', custom: ['New Company'])
    ], custom_columns: ['Company'])

    json = post_import(file, dry_run: false)
    expect(json['data']['updated']['count']).to eq(1)

    ticket = organizer_event.tickets.find_by(attendee_name: 'Ivan Kumar')
    expect(ticket.payment_status).to eq('paid')
    expect(ticket.custom_fields_data['company']).to eq('New Company')
  end

  it '5a. blank custom cell keeps existing value by default' do
    organizer_event.tickets.create!(ticket_type: ga_type, attendee_name: 'Keep Blank', status: :purchased,
                                    payment_status: :pending, custom_fields_data: { 'company' => 'Stored Co' })
    organizer_event.update!(labels_data: { 'company' => 'Company' })

    file = build_xlsx([row(name: 'Keep Blank', event: organizer_event.title, custom: [''])], custom_columns: ['Company'])
    post_import(file, dry_run: false)

    expect(organizer_event.tickets.find_by(attendee_name: 'Keep Blank').custom_fields_data['company']).to eq('Stored Co')
  end

  it '5b. blank custom cell clears value when overwrite_blank_custom_fields=true' do
    organizer_event.tickets.create!(ticket_type: ga_type, attendee_name: 'Clear Blank', status: :purchased,
                                    payment_status: :pending, custom_fields_data: { 'company' => 'Stored Co' })
    organizer_event.update!(labels_data: { 'company' => 'Company' })

    file = build_xlsx([row(name: 'Clear Blank', event: organizer_event.title, custom: [''])], custom_columns: ['Company'])
    post_import(file, dry_run: false, overwrite_blank_custom_fields: true)

    expect(organizer_event.tickets.find_by(attendee_name: 'Clear Blank').custom_fields_data['company']).to eq('')
  end

  it '6. duplicate rows in one file create one and flag the rest as duplicates' do
    file = build_xlsx([
      row(name: 'Kevin Ong', event: 'Scenario Dup', custom: ['Dup Co']),
      row(name: 'Kevin Ong', event: 'Scenario Dup', custom: ['Dup Co']),
      row(name: 'KEVIN ONG', event: 'Scenario Dup', custom: ['Dup Co'])
    ], custom_columns: ['Company'])

    json = post_import(file, dry_run: false)
    expect(json['data']['created']['count']).to eq(1)
    expect(json['data']['duplicates_in_file']['count']).to eq(2)
  end

  it '7. dry-run preview persists no event, ticket type, or ticket' do
    file = build_xlsx([row(name: 'Laura Teh', event: 'DryRun No Persist', type: 'DryRunType')])

    expect do
      post_import(file, dry_run: true)
    end.not_to change(Event, :count)

    expect(Event.find_by(title: 'DryRun No Persist')).to be_nil
    expect(TicketType.find_by(name: 'DryRunType')).to be_nil
  end

  it '7b. dry-run preview does not mutate the existing event or its tickets' do
    organizer_event.update!(labels_data: { 'company' => 'Company' })
    ticket = organizer_event.tickets.create!(
      ticket_type: ga_type, attendee_name: 'DryRun Existing', status: :purchased,
      payment_status: :pending, custom_fields_data: { 'company' => 'Old Co' }
    )
    original_labels = organizer_event.labels_data.deep_dup

    file = build_xlsx([
      row(name: 'DryRun Existing', event: organizer_event.title, payment: 'paid', custom: ['New Co'])
    ], custom_columns: ['Company'])

    post_import(file, dry_run: true)

    # Nothing may change on a preview: not the ticket's payment/custom fields,
    # and not the event's labels_data schema.
    ticket.reload
    expect(ticket.payment_status).to eq('pending')
    expect(ticket.custom_fields_data['company']).to eq('Old Co')
    expect(organizer_event.reload.labels_data).to eq(original_labels)
  end

  it '8. invalid rows are skipped/errored while valid rows still import' do
    file = build_xlsx([
      ['', 'noname@example.com', '', 'Scenario Valid C', 'General Admission', 'Delegate', '', '', 'paid', 'false', '', ''],
      ['No Event Person', 'noevent@example.com', '', '', 'General Admission', 'Delegate', '', '', 'paid', 'false', '', ''],
      ['', '', '', '', '', '', '', '', '', '', '', ''],
      row(name: 'Valid Person', email: 'valid@example.com', event: 'Scenario Valid C')
    ])

    json = post_import(file, dry_run: false)
    expect(json['data']['created']['count']).to eq(1)
    expect(Event.find_by(title: 'Scenario Valid C').tickets.find_by(attendee_name: 'Valid Person')).to be_present
  end

  it '9. ticket imported as checked-in can be unscanned (EF-309)' do
    file = build_xlsx([row(name: 'Marcus Goh', event: 'Scenario Checked In', checked_in: 'true')])
    post_import(file, dry_run: false)

    ticket = Event.find_by(title: 'Scenario Checked In').tickets.find_by(attendee_name: 'Marcus Goh')
    expect(ticket.checked_in).to be true
    expect(ScanLog.for_scannable(ticket)).to be_empty

    owner = create(:user, :org_owner)
    owner_headers = { 'Authorization' => "Bearer #{JwtService.generate_tokens(owner)[:access_token]}" }
    patch "/v1/tickets/#{ticket.id}/unscan", headers: owner_headers
    expect(response).to have_http_status(:ok)
    expect(ticket.reload.checked_in).to be false
  end

  it '10. payment status upgrades pending->paid but never downgrades paid->pending' do
    organizer_event.tickets.create!(ticket_type: ga_type, attendee_name: 'Nina Patel', status: :purchased, payment_status: :paid)
    organizer_event.tickets.create!(ticket_type: ga_type, attendee_name: 'Oscar Rao', status: :purchased, payment_status: :pending)

    file = build_xlsx([
      row(name: 'Nina Patel', event: organizer_event.title, payment: 'pending'),
      row(name: 'Oscar Rao', event: organizer_event.title, payment: 'paid')
    ])
    post_import(file, dry_run: false)

    expect(organizer_event.tickets.find_by(attendee_name: 'Nina Patel').payment_status).to eq('paid')
    expect(organizer_event.tickets.find_by(attendee_name: 'Oscar Rao').payment_status).to eq('paid')
  end

  it '11. one file can legitimately target multiple events' do
    file = build_xlsx([
      row(name: 'Paula Sim', event: 'Scenario Multi 1'),
      row(name: 'Quincy Tay', event: 'Scenario Multi 2')
    ])

    json = post_import(file, dry_run: false)
    expect(json['data']['created']['count']).to eq(2)
    expect(Event.find_by(title: 'Scenario Multi 1').tickets.find_by(attendee_name: 'Paula Sim')).to be_present
    expect(Event.find_by(title: 'Scenario Multi 2').tickets.find_by(attendee_name: 'Quincy Tay')).to be_present
  end

  it '12. removing a custom column from the file preserves the stored value' do
    # Ticket already has two custom fields stored.
    organizer_event.update!(labels_data: { 'company' => 'Company', 'team' => 'Team' })
    organizer_event.tickets.create!(
      ticket_type: ga_type, attendee_name: 'Column Removed', status: :purchased, payment_status: :paid,
      custom_fields_data: { 'company' => 'Acme', 'team' => 'Blue' }
    )

    # Reimport WITHOUT the Team column (it was removed from the file), changing Company.
    file = build_xlsx([
      row(name: 'Column Removed', event: organizer_event.title, custom: ['Acme Updated'])
    ], custom_columns: ['Company'])
    post_import(file, dry_run: false)

    ticket = organizer_event.tickets.find_by(attendee_name: 'Column Removed')
    expect(ticket.custom_fields_data['company']).to eq('Acme Updated')
    # Team column was removed from the file — its stored value must survive.
    expect(ticket.custom_fields_data['team']).to eq('Blue')
  end

  it '13. removing a custom column clears the value when overwrite_blank_custom_fields=true' do
    organizer_event.update!(labels_data: { 'company' => 'Company', 'team' => 'Team' })
    organizer_event.tickets.create!(
      ticket_type: ga_type, attendee_name: 'Column Reset', status: :purchased, payment_status: :paid,
      custom_fields_data: { 'company' => 'Acme', 'team' => 'Blue' }
    )

    file = build_xlsx([
      row(name: 'Column Reset', event: organizer_event.title, custom: ['Acme Updated'])
    ], custom_columns: ['Company'])
    post_import(file, dry_run: false, overwrite_blank_custom_fields: true)

    ticket = organizer_event.tickets.find_by(attendee_name: 'Column Reset')
    expect(ticket.custom_fields_data['company']).to eq('Acme Updated')
    # Reset mode: the removed Team column is cleared.
    expect(ticket.custom_fields_data['team']).to eq('')
  end
end
