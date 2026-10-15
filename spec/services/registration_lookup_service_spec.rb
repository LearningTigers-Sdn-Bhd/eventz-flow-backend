require 'rails_helper'

RSpec.describe RegistrationLookupService do
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
                   attendee_email: 'driver@example.com', attendee_name: 'Ali', role: 'Driver',
                   status: :purchased, payment_status: :paid)
  end

  def lookup(plate:, email:)
    described_class.new(event: event, plate: plate, email: email).call
  end

  it 'finds the ticket when plate and email both match, case-insensitively' do
    result = lookup(plate: 'sab-1234', email: 'DRIVER@example.com')
    expect(result).to eq(ticket)
  end

  it 'returns nil when the plate does not exist for this event' do
    expect(lookup(plate: 'SAB 9999', email: 'driver@example.com')).to be_nil
  end

  it 'returns nil when the plate exists but the email does not match any occupant' do
    expect(lookup(plate: 'SAB 1234', email: 'someone-else@example.com')).to be_nil
  end

  it 'returns nil for a canceled ticket even if plate and email match' do
    ticket.update!(status: :canceled)
    expect(lookup(plate: 'SAB 1234', email: 'driver@example.com')).to be_nil
  end

  it 'returns nil for a refunded ticket even if plate and email match' do
    ticket.update!(status: :refunded)
    expect(lookup(plate: 'SAB 1234', email: 'driver@example.com')).to be_nil
  end

  it 'matches a second occupant of the same vehicle by their own email' do
    co_driver = create(:ticket, event: event, ticket_type: ticket_type, vehicle_registration: vehicle,
                                 attendee_email: 'codriver@example.com', role: 'Co-Driver',
                                 status: :purchased, payment_status: :paid)

    expect(lookup(plate: 'SAB 1234', email: 'codriver@example.com')).to eq(co_driver)
  end

  it 'returns nil for a blank plate or email' do
    expect(lookup(plate: '', email: 'driver@example.com')).to be_nil
    expect(lookup(plate: 'SAB 1234', email: '')).to be_nil
  end
end
