require 'rails_helper'

RSpec.describe RegistrationUpdateService do
  let(:event) { create(:event, status: :published) }
  let(:form) { create(:registration_form, event: event, slug: 'competition', name: 'Competition') }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Competition - Member') }
  let!(:vehicle) do
    VehicleRegistration.create!(
      event: event, registration_form: form, base_ticket_type: ticket_type,
      plate: 'SAB 1234', normalized_plate: VehicleRegistration.normalize_plate('SAB 1234')
    )
  end
  let!(:ticket) do
    create(:ticket, event: event, ticket_type: ticket_type, vehicle_registration: vehicle,
                   attendee_email: 'driver@example.com', attendee_name: 'Ali', attendee_phone: '+60123456789',
                   role: 'Driver', status: :purchased, payment_status: :paid,
                   custom_fields_data: { 'ic_passport_no' => '900101015555' })
  end

  def update(public_id: ticket.public_id, plate: 'SAB 1234', email: 'driver@example.com', attributes: {}, documents: {})
    described_class.new(
      event: event, plate: plate, email: email, public_id: public_id, attributes: attributes, documents: documents
    ).call
  end

  it 'updates editable fields when plate and email match' do
    result = update(attributes: { attendee_phone: '+60129998888', role: 'Driver' })

    expect(result).to be_success
    expect(result.ticket.reload.attendee_phone).to eq('+60129998888')
  end

  it 'is not found when plate and email do not match' do
    result = update(email: 'wrong@example.com')

    expect(result).not_to be_success
    expect(result.errors).to include(a_string_matching(/couldn't find/i))
  end

  it 'never assigns attendee_email even if present in attributes' do
    result = update(attributes: { attendee_email: 'new-email@example.com' })

    expect(result).to be_success
    expect(result.ticket.reload.attendee_email).to eq('driver@example.com')
  end

  it 'strips reserved custom_fields_data keys' do
    result = update(attributes: { custom_fields_data: { '_indemnity' => { 'accepted' => true }, 'ic_passport_no' => '900101015555' } })

    expect(result).to be_success
    expect(result.ticket.reload.custom_fields_data).not_to have_key('_indemnity')
  end

  it 'rejects a role change to one already taken by another active occupant of the vehicle' do
    create(:ticket, event: event, ticket_type: ticket_type, vehicle_registration: vehicle,
                   attendee_email: 'codriver@example.com', role: 'Co-Driver',
                   status: :purchased, payment_status: :paid)

    result = update(attributes: { role: 'Co-Driver' })

    expect(result).not_to be_success
    expect(result.errors).to include(a_string_matching(/already has a Co-Driver/i))
  end

  it "allows keeping the ticket's own current single-occupant role" do
    result = update(attributes: { role: 'Driver' })

    expect(result).to be_success
  end

  it 'rejects a duplicate ic_passport_no already used by another ticket in the event' do
    create(:ticket, event: event, ticket_type: ticket_type,
                   custom_fields_data: { 'ic_passport_no' => '850505085555' })

    result = update(attributes: { custom_fields_data: { 'ic_passport_no' => '850505085555' } })

    expect(result).not_to be_success
    expect(result.errors).to include(a_string_matching(/already registered/i))
  end

  it 'replaces a document via RegistrationDocumentAttacher with replace_existing: true' do
    old_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('old'), filename: 'old.jpg', content_type: 'image/jpeg',
      metadata: { document_key: 'passport_copy', event_id: event.id, uploaded_at: Time.current.iso8601 }
    )
    ticket.registration_documents.attach(old_blob)
    new_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('new'), filename: 'new.jpg', content_type: 'image/jpeg',
      metadata: { document_key: 'passport_copy', event_id: event.id, uploaded_at: Time.current.iso8601 }
    )

    result = update(documents: { passport_copy: new_blob.signed_id })

    expect(result).to be_success
    expect(ticket.reload.registration_documents.count).to eq(1)
    expect(ticket.registration_documents.first.blob).to eq(new_blob)
  end
end
