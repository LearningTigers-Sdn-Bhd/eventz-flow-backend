require 'rails_helper'

RSpec.describe 'V1::Public::VehicleRegistrations', type: :request do
  let(:event) { create(:event, status: :published) }
  let(:expedition_form) do
    create(:registration_form, event: event, slug: 'expedition-tags-on', name: 'Expedition (Tags-on)')
  end
  let(:expedition_a_form) do
    create(:registration_form, event: event, slug: 'expedition-a-tags-on', name: 'Expedition A (Tags-on)')
  end
  let(:competition_form) do
    create(:registration_form, event: event, slug: 'competition', name: 'Competition')
  end
  let(:support_form) do
    create(:registration_form, event: event, slug: 'competitor-support', name: 'Competitor Support')
  end
  let(:official_crew_form) do
    create(:registration_form, event: event, slug: 'official-crew', name: 'Official Crew')
  end

  let!(:expedition_member) { ticket_type('Expedition - Member', 800, expedition_form) }
  let!(:expedition_a_member) { ticket_type('Expedition - Member', 800, expedition_a_form) }
  let!(:expedition_corporate) { ticket_type('Expedition - Corporate', 3000, expedition_form) }
  let!(:expedition_non_member) { ticket_type('Expedition - Non-Member', 1600, expedition_form) }
  let!(:expedition_international) { ticket_type('Expedition - International', 1600, expedition_form) }
  let!(:included_member) { ticket_type('Included 2nd Person - Member/Corporate', 0, expedition_form) }
  let!(:additional_member) { ticket_type('Additional Person - Member', 400, expedition_form) }
  let!(:additional_non_member) { ticket_type('Additional Person - Non-Member', 800, expedition_form) }
  let!(:competition_member) { ticket_type('Competition - Member', 800, competition_form) }
  let!(:competition_non_member) { ticket_type('Competition - Non-Member', 1600, competition_form) }
  let!(:competition_included) { ticket_type('Included 2nd Person (Team of 2)', 0, competition_form) }
  let!(:reserve_member) { ticket_type('Reserve Co-Driver - Member', 400, competition_form) }
  let!(:reserve_other) do
    ticket_type('Reserve Co-Driver - Non-Member/International/Corporate', 800, competition_form)
  end
  let!(:support_member) { ticket_type('Support - Member', 800, support_form) }
  let!(:support_non_member) { ticket_type('Support - Non-Member', 1600, support_form) }
  let!(:support_included) { ticket_type('Included 2nd Person - Member/Corporate', 0, support_form) }
  let!(:support_additional_member) { ticket_type('Additional Person - Member', 400, support_form) }
  let!(:support_additional_non_member) { ticket_type('Additional Person - Non-Member', 800, support_form) }
  let!(:official_crew_member) { ticket_type('Official Crew - Member', 0, official_crew_form) }
  let!(:official_crew_non_member) { ticket_type('Official Crew - Non-Member', 0, official_crew_form) }

  def ticket_type(name, price, form)
    value = create(:ticket_type, event: event, name: name, price: price, status: :published, hidden: false)
    create(:registration_form_ticket_type, registration_form: form, ticket_type: value)
    value
  end

  def lookup(form:, plate:)
    get "/v1/public/events/#{event.slug}/vehicle_registration",
        params: { form_slug: form.slug, plate: plate }
  end

  def valid_terms
    {
      accepted: true,
      method: 'checkbox_typed_name',
      acknowledged_name: 'Ali Bin Ahmad',
      terms_version: 'borneo-safari-sabah-registration-terms-v1'
    }
  end

  def upload_blob(key)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("#{key} image bytes"),
      filename: "#{key}.jpg",
      content_type: 'image/jpeg',
      metadata: { document_key: key, event_id: event.id, uploaded_at: Time.current.iso8601 }
    )
  end

  def vehicle_documents
    {
      passport_copy: upload_blob('passport_copy').signed_id,
      photo_1: upload_blob('photo_1').signed_id
    }
  end

  def register(form:, ticket_type:, plate:, email:, attendee_name: 'Ali Bin Ahmad', **extra)
    post "/v1/public/events/#{event.slug}/register", params: {
      form_slug: form.slug,
      ticket_type_id: ticket_type.id,
      vehicle_plate: plate,
      attendee_name: attendee_name,
      attendee_email: email,
      attendee_phone: '+60123456789',
      terms_agreement: valid_terms,
      documents: vehicle_documents
    }.merge(extra), as: :json
  end

  it 'requires terms acceptance for vehicle registration' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAA 1',
      email: 'terms-required@example.com',
      terms_agreement: nil
    )

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch('errors')).to include(/terms must be accepted/i)
    expect(event.tickets.where(attendee_email: 'terms-required@example.com')).to be_empty
  end

  it 'requires the identity copy and camera photo for vehicle registration' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAA 2',
      email: 'documents-required@example.com',
      documents: {}
    )

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch('errors')).to include(/passport_copy.*photo_1/i)
    expect(event.tickets.where(attendee_email: 'documents-required@example.com')).to be_empty
  end

  it 'creates a vehicle registration for a split expedition sub-form (expedition-a-tags-on)' do
    register(
      form: expedition_a_form,
      ticket_type: expedition_a_member,
      plate: 'SAA A1',
      email: 'expedition-a@example.com'
    )

    expect(response).to have_http_status(:created)
    ticket = event.tickets.find_by(attendee_email: 'expedition-a@example.com')
    expect(ticket.vehicle_registration).to be_present
    expect(ticket.vehicle_registration.registration_form).to eq(expedition_a_form)
  end

  it 'requires terms acceptance and documents for a split expedition sub-form (expedition-a-tags-on)' do
    register(
      form: expedition_a_form,
      ticket_type: expedition_a_member,
      plate: 'SAA A2',
      email: 'expedition-a-terms@example.com',
      terms_agreement: nil
    )

    expect(response).to have_http_status(:unprocessable_content)
    expect(event.tickets.where(attendee_email: 'expedition-a-terms@example.com')).to be_empty
  end

  it 'offers only main vehicle tickets for a new normalized plate' do
    lookup(form: expedition_form, plate: ' SAA-1234 a ')

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body).fetch('data')
    expect(data).to include(
      'status' => 'new',
      'plate' => 'SAA1234A',
      'occupancy' => 0,
      'capacity' => 4
    )
    expect(data.fetch('allowed_ticket_type_ids')).to contain_exactly(
      expedition_member.id,
      expedition_corporate.id,
      expedition_non_member.id,
      expedition_international.id
    )
  end

  it 'offers the included second-person ticket for a member vehicle' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAA 1234 A',
      email: 'driver@example.com'
    )

    expect(response).to have_http_status(:created)

    lookup(form: expedition_form, plate: 'saa-1234-a')

    data = JSON.parse(response.body).fetch('data')
    expect(data).to include('status' => 'existing', 'occupancy' => 1)
    expect(data.fetch('allowed_ticket_type_ids')).to eq([included_member.id])
  end

  it 'offers both paid additional tickets for person two of a non-member vehicle' do
    register(
      form: expedition_form,
      ticket_type: expedition_non_member,
      plate: 'SAB 88',
      email: 'driver@example.com'
    )

    lookup(form: expedition_form, plate: 'sab88')

    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      additional_member.id, additional_non_member.id
    )
  end

  it 'rejects a ticket that is not eligible for the next vehicle occupant' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAC 99',
      email: 'driver@example.com'
    )

    register(
      form: expedition_form,
      ticket_type: additional_member,
      plate: 'sac99',
      email: 'passenger@example.com'
    )

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch('message')).to match(/included second person/i)
    expect(event.tickets.count).to eq(1)
  end

  it 'blocks a plate selected under a different registration category' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAD 10',
      email: 'driver@example.com'
    )

    lookup(form: competition_form, plate: 'sad10')

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch('data')).to include(
      'status' => 'wrong_form',
      'registered_form_slug' => 'expedition-tags-on',
      'registered_form_name' => 'Expedition (Tags-on)',
      'allowed_ticket_type_ids' => []
    )
  end

  it 'follows the vehicle category when its base ticket is changed' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAD 11',
      email: 'moved-driver@example.com'
    )
    driver_ticket = event.tickets.find_by!(attendee_email: 'moved-driver@example.com')

    driver_ticket.update!(ticket_type_id: competition_member.id)

    lookup(form: competition_form, plate: 'sad11')

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch('data')).to include(
      'status' => 'existing',
      'registered_form_slug' => 'competition',
      'registered_form_name' => 'Competition',
      'allowed_ticket_type_ids' => [competition_included.id]
    )
    expect(driver_ticket.reload.vehicle_registration.registration_form).to eq(competition_form)
    expect(driver_ticket.vehicle_registration.base_ticket_type).to eq(competition_member)
  end

  it 'rejects changing a vehicle category while additional participants are active' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAD 12',
      email: 'occupied-driver@example.com'
    )
    register(
      form: expedition_form,
      ticket_type: included_member,
      plate: 'SAD 12',
      email: 'occupied-passenger@example.com'
    )
    driver_ticket = event.tickets.find_by!(attendee_email: 'occupied-driver@example.com')

    expect {
      driver_ticket.update!(ticket_type_id: competition_member.id)
    }.to raise_error(
      VehicleRegistrationTicketTypeSync::Error,
      /additional active participants/i
    )

    expect(driver_ticket.reload.ticket_type).to eq(expedition_member)
    expect(driver_ticket.vehicle_registration.registration_form).to eq(expedition_form)
    expect(driver_ticket.vehicle_registration.base_ticket_type).to eq(expedition_member)
  end

  it 'allows swapping the base ticket between member/non-member within the same category, even with other active participants' do
    register(
      form: official_crew_form,
      ticket_type: official_crew_non_member,
      plate: 'SAD 13',
      email: 'crew-base@example.com',
      role: 'Driver'
    )
    register(
      form: official_crew_form,
      ticket_type: official_crew_non_member,
      plate: 'SAD 13',
      email: 'crew-passenger@example.com',
      role: 'Co-Driver'
    )
    driver_ticket = event.tickets.find_by!(attendee_email: 'crew-base@example.com')

    expect {
      driver_ticket.update!(ticket_type_id: official_crew_member.id)
    }.not_to raise_error

    expect(driver_ticket.reload.ticket_type).to eq(official_crew_member)
    expect(driver_ticket.vehicle_registration.registration_form).to eq(official_crew_form)
    expect(driver_ticket.vehicle_registration.base_ticket_type).to eq(official_crew_member)
  end

  it 'adopts an existing custom-field plate into a vehicle registration' do
    legacy_ticket = create(
      :ticket,
      event: event,
      ticket_type: expedition_member,
      attendee_email: 'legacy@example.com',
      custom_fields_data: { 'car_registration_number' => 'SAE 500' }
    )

    lookup(form: expedition_form, plate: 'sae-500')

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch('data')).to include(
      'status' => 'existing',
      'occupancy' => 1,
      'allowed_ticket_type_ids' => [included_member.id]
    )
    expect(legacy_ticket.reload.vehicle_registration).to be_present
  end

  it 'includes the competition teammate, then offers both paid reserve co-driver tickets before becoming full' do
    register(
      form: competition_form,
      ticket_type: competition_member,
      plate: 'SAX 12',
      email: 'competition-driver@example.com'
    )
    lookup(form: competition_form, plate: 'sax12')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to eq(
      [competition_included.id]
    )

    register(
      form: competition_form,
      ticket_type: competition_included,
      plate: 'SAX-12',
      email: 'competition-codriver@example.com'
    )
    lookup(form: competition_form, plate: 'SAX 12')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      reserve_member.id, reserve_other.id
    )

    register(
      form: competition_form,
      ticket_type: reserve_member,
      plate: 'sax12',
      email: 'competition-reserve@example.com'
    )
    lookup(form: competition_form, plate: 'SAX12')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      reserve_member.id, reserve_other.id
    )

    register(
      form: competition_form,
      ticket_type: reserve_member,
      plate: 'sax-12',
      email: 'competition-reserve-2@example.com'
    )
    lookup(form: competition_form, plate: 'SAX 12')
    expect(JSON.parse(response.body).fetch('data')).to include(
      'status' => 'full',
      'occupancy' => 4,
      'capacity' => 4,
      'allowed_ticket_type_ids' => []
    )
  end

  it 'offers both reserve co-driver tickets for a non-member competition vehicle' do
    register(
      form: competition_form,
      ticket_type: competition_non_member,
      plate: 'SAY 13',
      email: 'competition-non-member-driver@example.com'
    )
    lookup(form: competition_form, plate: 'say13')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to eq(
      [competition_included.id]
    )

    register(
      form: competition_form,
      ticket_type: competition_included,
      plate: 'SAY-13',
      email: 'competition-non-member-codriver@example.com'
    )
    lookup(form: competition_form, plate: 'SAY 13')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      reserve_member.id, reserve_other.id
    )
  end

  it 'applies member and non-member occupant pricing to competitor support vehicles' do
    register(
      form: support_form,
      ticket_type: support_member,
      plate: 'SS 100',
      email: 'support-member-driver@example.com'
    )
    lookup(form: support_form, plate: 'ss100')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to eq(
      [support_included.id]
    )

    register(
      form: support_form,
      ticket_type: support_included,
      plate: 'SS 100',
      email: 'support-member-passenger@example.com'
    )
    lookup(form: support_form, plate: 'ss100')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      support_additional_member.id, support_additional_non_member.id
    )

    register(
      form: support_form,
      ticket_type: support_non_member,
      plate: 'SS 200',
      email: 'support-nonmember-driver@example.com'
    )
    lookup(form: support_form, plate: 'ss200')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      support_additional_member.id, support_additional_non_member.id
    )
  end

  it 'does not retain an empty vehicle group when its first ticket fails validation' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAZ 404',
      email: 'invalid-driver@example.com',
      attendee_name: ''
    )

    expect(response).to have_http_status(:unprocessable_content)
    expect(VehicleRegistration.find_by(event: event, normalized_plate: 'SAZ404')).to be_nil

    register(
      form: expedition_form,
      ticket_type: expedition_non_member,
      plate: 'saz-404',
      email: 'valid-driver@example.com'
    )
    expect(response).to have_http_status(:created)

    lookup(form: expedition_form, plate: 'SAZ 404')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      additional_member.id, additional_non_member.id
    )
  end

  it 'rejects vehicle ticket registration that omits its registration form' do
    post "/v1/public/events/#{event.slug}/register", params: {
      ticket_type_id: expedition_member.id,
      vehicle_plate: 'SAY 100',
      attendee_name: 'Formless Driver',
      attendee_email: 'formless@example.com',
      attendee_phone: '+60123456789'
    }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch('message')).to match(/registration form is required/i)
    expect(event.tickets.where(attendee_email: 'formless@example.com')).to be_empty
  end

  it 'still rejects a form-less vehicle ticket when its form was deactivated' do
    expedition_form.update!(status: :closed)

    post "/v1/public/events/#{event.slug}/register", params: {
      ticket_type_id: expedition_member.id,
      vehicle_plate: 'SAY 101',
      attendee_name: 'Inactive Form Driver',
      attendee_email: 'inactive-formless@example.com',
      attendee_phone: '+60123456789'
    }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch('message')).to match(/registration form is required/i)
    expect(event.tickets.where(attendee_email: 'inactive-formless@example.com')).to be_empty
  end

  it 'replaces the base pricing class after the original base occupant is canceled' do
    register(
      form: expedition_form,
      ticket_type: expedition_member,
      plate: 'SAW 77',
      email: 'canceled-member@example.com'
    )
    event.tickets.find_by!(attendee_email: 'canceled-member@example.com').update!(status: :canceled)

    register(
      form: expedition_form,
      ticket_type: expedition_non_member,
      plate: 'saw77',
      email: 'replacement-nonmember@example.com'
    )
    expect(response).to have_http_status(:created)

    lookup(form: expedition_form, plate: 'SAW-77')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      additional_member.id, additional_non_member.id
    )
  end

  it 'offers every official crew seat an open member/non-member choice, up to a car of 4' do
    register(
      form: official_crew_form,
      ticket_type: official_crew_non_member,
      plate: 'SAZ 20',
      email: 'crew-driver@example.com',
      role: 'Driver'
    )

    lookup(form: official_crew_form, plate: 'saz20')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      official_crew_member.id, official_crew_non_member.id
    )

    register(
      form: official_crew_form,
      ticket_type: official_crew_member,
      plate: 'SAZ-20',
      email: 'crew-2@example.com',
      role: 'Co-Driver'
    )

    lookup(form: official_crew_form, plate: 'SAZ 20')
    expect(JSON.parse(response.body).dig('data', 'allowed_ticket_type_ids')).to contain_exactly(
      official_crew_member.id, official_crew_non_member.id
    )

    register(
      form: official_crew_form,
      ticket_type: official_crew_non_member,
      plate: 'saz-20',
      email: 'crew-3@example.com',
      role: 'Passenger'
    )
    register(
      form: official_crew_form,
      ticket_type: official_crew_non_member,
      plate: 'SAZ20',
      email: 'crew-4@example.com',
      role: 'Passenger'
    )

    lookup(form: official_crew_form, plate: 'SAZ 20')
    expect(JSON.parse(response.body).fetch('data')).to include(
      'status' => 'full',
      'occupancy' => 4,
      'capacity' => 4,
      'allowed_ticket_type_ids' => []
    )
  end
end
