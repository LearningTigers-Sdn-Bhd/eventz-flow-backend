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

  it 'rolls back other edits when the plate is rejected' do
    create_ticket(type: competition_member, plate: 'SAA8466H')
    ticket = create(:ticket, event: event, ticket_type: competition_member, role: 'Driver', attendee_name: 'Old')

    put "/v1/events/#{event.id}/tickets/#{ticket.public_id}", headers: headers,
        params: { ticket: { attendee_name: 'New', custom_fields_data: { car_registration_number: 'SAA8466H' } } },
        as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(ticket.reload.attendee_name).to eq('Old')
  end
end
