require 'rails_helper'

RSpec.describe 'V1::Public::Registrations edit', type: :request do
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
                   role: 'Driver', status: :purchased, payment_status: :paid)
  end

  describe 'GET /v1/public/events/:event_slug/registration_lookup' do
    it 'returns the matched ticket when plate and email match' do
      get "/v1/public/events/#{event.slug}/registration_lookup", params: { plate: 'SAB 1234', email: 'driver@example.com' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']['public_id']).to eq(ticket.public_id)
      expect(json['data']['form_slug']).to eq('competition')
      expect(json['data']['attendee_name']).to eq('Ali')
      expect(json['data']['ticket_type_id']).to eq(ticket_type.id)
    end

    it 'returns a generic 404 when the plate does not exist' do
      get "/v1/public/events/#{event.slug}/registration_lookup", params: { plate: 'SAB 9999', email: 'driver@example.com' }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['message']).to match(/couldn't find/i)
    end

    it 'returns the same generic 404 when the plate exists but the email is wrong' do
      get "/v1/public/events/#{event.slug}/registration_lookup", params: { plate: 'SAB 1234', email: 'wrong@example.com' }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['message']).to match(/couldn't find/i)
    end
  end

  describe 'PATCH /v1/public/events/:event_slug/registrations/:public_id' do
    def patch_edit(public_id: ticket.public_id, **body)
      patch "/v1/public/events/#{event.slug}/registrations/#{public_id}",
            params: { plate: 'SAB 1234', email: 'driver@example.com' }.merge(body), as: :json
    end

    it 'updates editable fields' do
      patch_edit(attendee_phone: '+60129998888', role: 'Driver')

      expect(response).to have_http_status(:ok)
      expect(ticket.reload.attendee_phone).to eq('+60129998888')
    end

    it 'ignores attendee_email, plate, and ticket_type_id in the body' do
      other_ticket_type = create(:ticket_type, event: event, name: 'Competition - Non-Member')

      patch_edit(attendee_email: 'new@example.com', vehicle_plate: 'SAB 9999', ticket_type_id: other_ticket_type.id)

      expect(response).to have_http_status(:ok)
      ticket.reload
      expect(ticket.attendee_email).to eq('driver@example.com')
      expect(ticket.ticket_type_id).to eq(ticket_type.id)
      expect(ticket.vehicle_registration.normalized_plate).to eq('SAB1234')
    end

    it 'returns the generic 404 when plate/email no longer match' do
      patch "/v1/public/events/#{event.slug}/registrations/#{ticket.public_id}",
            params: { plate: 'SAB 1234', email: 'wrong@example.com', attendee_phone: '+60100000000' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(ticket.reload.attendee_phone).to eq('+60123456789')
    end

    it 'returns 422 with errors when a role conflict occurs' do
      create(:ticket, event: event, ticket_type: ticket_type, vehicle_registration: vehicle,
                     attendee_email: 'codriver@example.com', role: 'Co-Driver',
                     status: :purchased, payment_status: :paid)

      patch_edit(role: 'Co-Driver')

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['errors'].join).to match(/already has a Co-Driver/i)
    end
  end
end
