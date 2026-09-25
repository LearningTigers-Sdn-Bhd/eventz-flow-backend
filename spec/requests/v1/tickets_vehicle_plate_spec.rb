require 'rails_helper'

RSpec.describe 'V1::Tickets car plate', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }
  let(:event) do
    create(:event, payment_status: :paid).tap do |e|
      EventAssignment.find_or_create_by!(event: e, user: organizer, role: :event_admin)
    end
  end
  let(:form) { create(:registration_form, event: event, slug: 'competition', name: 'Competition') }
  let!(:competition_member) { ticket_type('Competition - Member', form) }
  let!(:competition_included) { ticket_type('Included 2nd Person (Team of 2)', form) }
  let!(:plain_type) { create(:ticket_type, event: event, name: 'GA') }

  def ticket_type(name, form)
    create(:ticket_type, event: event, name: name).tap do |tt|
      create(:registration_form_ticket_type, registration_form: form, ticket_type: tt)
    end
  end

  def create_ticket(type:, plate:, role: 'Driver')
    post "/v1/events/#{event.id}/tickets", headers: headers, params: {
      ticket: { attendee_name: 'Ali', attendee_email: "#{SecureRandom.hex(4)}@x.com", ticket_type_id: type.id,
                role: role, custom_fields_data: { car_registration_number: plate } }
    }, as: :json
  end

  it 'saves the plate on manual create (new car)' do
    create_ticket(type: competition_member, plate: 'saa 8466h')

    expect(response).to have_http_status(:created)
    ticket = Ticket.last
    expect(ticket.vehicle_registration.plate).to eq('SAA8466H')
    expect(ticket.custom_fields_data['car_registration_number']).to eq('SAA8466H')
  end

  it 'joins an existing car on manual create' do
    create_ticket(type: competition_member, plate: 'SAA8466H')
    create_ticket(type: competition_included, plate: 'SAA8466H', role: 'Co-Driver')

    expect(response).to have_http_status(:created)
    expect(VehicleRegistration.find_by(normalized_plate: 'SAA8466H').tickets.count).to eq(2)
  end

  it 'sets a plate when editing a ticket that had no car yet' do
    ticket = create(:ticket, event: event, ticket_type: competition_member, role: 'Driver')

    put "/v1/events/#{event.id}/tickets/#{ticket.public_id}", headers: headers,
        params: { ticket: { custom_fields_data: { car_registration_number: 'SAA8466H' } } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(ticket.reload.vehicle_registration.plate).to eq('SAA8466H')
  end

  it 'rejects a plate with a clear error instead of silently dropping it' do
    create_ticket(type: plain_type, plate: 'SAA8466H')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['errors'].first).to include('not part of any vehicle registration form')
    expect(Ticket.count).to eq(0)
  end

  it 'keeps reserved fields when an edit omits them' do
    create_ticket(type: competition_member, plate: 'SAA8466H')
    ticket = Ticket.last
    ticket.update_column(:custom_fields_data, ticket.custom_fields_data.merge('_indemnity' => { 'ok' => true }))

    put "/v1/events/#{event.id}/tickets/#{ticket.public_id}", headers: headers,
        params: { ticket: { custom_fields_data: { remarks: 'hi' } } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(ticket.reload.custom_fields_data).to include('car_registration_number' => 'SAA8466H',
                                                        '_indemnity' => { 'ok' => true }, 'remarks' => 'hi')
  end

  it 'refills a wiped plate field when the same plate is re-entered' do
    create_ticket(type: competition_member, plate: 'SAA8466H')
    ticket = Ticket.last
    ticket.update_column(:custom_fields_data, {})

    put "/v1/events/#{event.id}/tickets/#{ticket.public_id}", headers: headers,
        params: { ticket: { custom_fields_data: { car_registration_number: 'SAA8466H' } } }, as: :json

    expect(ticket.reload.custom_fields_data['car_registration_number']).to eq('SAA8466H')
  end

  it 'rolls back other edits when the plate is rejected' do
    create_ticket(type: competition_member, plate: 'SAA8466H')
    ticket = create(:ticket, event: event, ticket_type: competition_member, role: 'Driver', attendee_name: 'Old')

    put "/v1/events/#{event.id}/tickets/#{ticket.public_id}", headers: headers,
        params: { ticket: { attendee_name: 'New', custom_fields_data: { car_registration_number: 'SAA8466H' } } },
        as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(ticket.reload.attendee_name).to eq('Old')
  end

  describe 'changing expedition group' do
    let(:exp_a) { create(:registration_form, event: event, slug: 'expedition-a-tags-on', name: 'Expedition A') }
    let(:exp_b) { create(:registration_form, event: event, slug: 'expedition-b-tags-on', name: 'Expedition B') }
    # One "Expedition - Member" type shared across sub-forms, as locally.
    let!(:expedition_member) do
      ticket_type('Expedition - Member', exp_a).tap do |tt|
        create(:registration_form_ticket_type, registration_form: exp_b, ticket_type: tt)
      end
    end

    def update_ticket(ticket, attrs)
      put "/v1/events/#{event.id}/tickets/#{ticket.public_id}", headers: headers, params: { ticket: attrs }, as: :json
    end

    it 'moves a co-driver to a new car in the chosen group' do
      create_ticket(type: competition_member, plate: 'GTK1')
      create_ticket(type: competition_included, plate: 'GTK1', role: 'Co-Driver')
      co_driver = Ticket.last

      update_ticket(co_driver, ticket_type_id: expedition_member.id, role: 'Driver',
                               vehicle_registration_form_id: exp_b.id,
                               custom_fields_data: { car_registration_number: 'SA1088R' })

      expect(response).to have_http_status(:ok)
      expect(co_driver.reload.vehicle_registration.registration_form).to eq(exp_b)
      expect(co_driver.vehicle_registration.plate).to eq('SA1088R')
      expect(VehicleRegistration.find_by(normalized_plate: 'GTK1').active_tickets.count).to eq(1)
    end

    it 'moves a solo car to the chosen group without a new plate' do
      create_ticket(type: competition_member, plate: 'GTK2')
      driver = Ticket.last

      update_ticket(driver, ticket_type_id: expedition_member.id, vehicle_registration_form_id: exp_b.id)

      expect(response).to have_http_status(:ok)
      expect(driver.reload.vehicle_registration.registration_form).to eq(exp_b)
      expect(driver.vehicle_registration.plate).to eq('GTK2')
    end

    it 'refuses to move a car that still has crew' do
      create_ticket(type: competition_member, plate: 'GTK3')
      driver = Ticket.last
      create_ticket(type: competition_included, plate: 'GTK3', role: 'Co-Driver')

      update_ticket(driver, ticket_type_id: expedition_member.id, vehicle_registration_form_id: exp_b.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors'].first).to include('other crew')
      expect(driver.reload.vehicle_registration.registration_form).to eq(form)
    end

    it 'asks for the group instead of silently keeping the old one' do
      create_ticket(type: competition_member, plate: 'GTK4')
      driver = Ticket.last

      update_ticket(driver, ticket_type_id: expedition_member.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors'].first).to include('choose the expedition group')
      expect(driver.reload.ticket_type).to eq(competition_member)
    end
  end
end
