require 'rails_helper'

RSpec.describe 'V1::VehicleRegistrations', type: :request do
  let(:event) { create(:event, status: :published, vehicles_enabled: true) }

  let(:expedition_form) do
    create(:registration_form, event: event, slug: 'expedition-tags-on', name: 'Expedition (Tags-on)')
  end
  let(:expedition_b_form) do
    create(:registration_form, event: event, slug: 'expedition-b-tags-on', name: 'Expedition B (Tags-on)')
  end
  let(:support_form) do
    create(:registration_form, event: event, slug: 'competitor-support', name: 'Competitor Support')
  end

  let!(:expedition_member) { ticket_type('Expedition - Member', 800, expedition_form) }
  let!(:expedition_b_member) { ticket_type('Expedition - Member', 800, expedition_b_form) }
  let!(:additional_member) { ticket_type('Additional Person - Member', 400, expedition_form) }
  let!(:support_member) { ticket_type('Support - Member', 800, support_form) }
  let!(:support_additional_member) { ticket_type('Additional Person - Member', 400, support_form) }

  let(:admin) { create(:user, :org_owner) }
  let(:admin_token) { JwtService.generate_tokens(admin)[:access_token] }
  let(:headers) { { 'Authorization' => "Bearer #{admin_token}" } }

  def ticket_type(name, price, form)
    value = create(:ticket_type, event: event, name: name, price: price, status: :published, hidden: false)
    create(:registration_form_ticket_type, registration_form: form, ticket_type: value)
    value
  end

  def vehicle(plate:, form:, base:)
    VehicleRegistration.create!(
      event: event,
      registration_form: form,
      base_ticket_type: base,
      plate: plate,
      normalized_plate: VehicleRegistration.normalize_plate(plate)
    )
  end

  def crew(vehicle:, ticket_type:, name:, role: 'Passenger', status: :purchased)
    create(:ticket,
           event: event,
           ticket_type: ticket_type,
           vehicle_registration: vehicle,
           attendee_name: name,
           role: role,
           status: status)
  end

  describe 'GET /v1/events/:event_id/vehicle_registrations' do
    it 'lists cars with group, seats, crew, and issues' do
      car = vehicle(plate: 'SAA 2000', form: expedition_form, base: expedition_member)
      driver = crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      crew(vehicle: car, ticket_type: additional_member, name: 'Passenger One')

      get "/v1/events/#{event.id}/vehicle_registrations", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)

      entry = body.first
      expect(entry['plate']).to eq('SAA 2000')
      expect(entry['registration_form']).to eq(
        'id' => expedition_form.id, 'name' => expedition_form.name, 'slug' => expedition_form.slug
      )
      expect(entry['base_ticket_type']).to eq('id' => expedition_member.id, 'name' => expedition_member.name)
      expect(entry['capacity']).to eq(4)
      expect(entry['seats_used']).to eq(2)
      expect(entry['issues']).to eq([])

      driver_entry = entry['crew'].find { |member| member['ticket_id'] == driver.id }
      expect(driver_entry).to include(
        'public_id' => driver.public_id,
        'name' => 'Driver One',
        'role' => 'Driver',
        'ticket_type_name' => expedition_member.name,
        'status' => 'purchased',
        'payment_status' => 'pending'
      )
    end

    it 'does not count canceled or refunded crew toward seats' do
      car = vehicle(plate: 'SAA 2001', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      crew(vehicle: car, ticket_type: additional_member, name: 'Gone Passenger', status: :canceled)

      get "/v1/events/#{event.id}/vehicle_registrations", headers: headers

      entry = JSON.parse(response.body).first
      expect(entry['seats_used']).to eq(1)
      expect(entry['crew'].size).to eq(1)
    end

    it 'returns 404 when the event does not have vehicles enabled' do
      event.update!(vehicles_enabled: false)

      get "/v1/events/#{event.id}/vehicle_registrations", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'filters by registration_form_id' do
      vehicle(plate: 'SAA 2002', form: expedition_form, base: expedition_member)
      vehicle(plate: 'SAA 2003', form: support_form, base: support_member)

      get "/v1/events/#{event.id}/vehicle_registrations",
          params: { registration_form_id: support_form.id }, headers: headers

      body = JSON.parse(response.body)
      expect(body.map { |car| car['plate'] }).to eq(['SAA 2003'])
    end

    it 'searches by plate or crew name' do
      car = vehicle(plate: 'SAA 2004', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Ahmad Driver', role: 'Driver')
      other = vehicle(plate: 'SAA 2005', form: expedition_form, base: expedition_member)
      crew(vehicle: other, ticket_type: expedition_member, name: 'Someone Else', role: 'Driver')

      get "/v1/events/#{event.id}/vehicle_registrations", params: { q: 'ahmad' }, headers: headers
      expect(JSON.parse(response.body).map { |c| c['plate'] }).to eq(['SAA 2004'])

      get "/v1/events/#{event.id}/vehicle_registrations", params: { q: '2005' }, headers: headers
      expect(JSON.parse(response.body).map { |c| c['plate'] }).to eq(['SAA 2005'])
    end

    it 'filters to cars with issues only' do
      clean = vehicle(plate: 'SAA 2006', form: expedition_form, base: expedition_member)
      crew(vehicle: clean, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      stale = vehicle(plate: 'SAA 2007', form: expedition_form, base: expedition_b_member)
      crew(vehicle: stale, ticket_type: expedition_member, name: 'Driver Two', role: 'Driver')

      get "/v1/events/#{event.id}/vehicle_registrations", params: { issues_only: 'true' }, headers: headers

      body = JSON.parse(response.body)
      expect(body.map { |car| car['plate'] }).to eq(['SAA 2007'])
      expect(body.first['issues'].map { |issue| issue['code'] }).to include('stale_base')
    end

    it 'does not flag a car whose registrant holds the base ticket but is not labelled Driver' do
      car = vehicle(plate: 'SAA 2008', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Registrant', role: 'Passenger')
      crew(vehicle: car, ticket_type: additional_member, name: 'Actual Driver', role: 'Driver')

      get "/v1/events/#{event.id}/vehicle_registrations", headers: headers

      entry = JSON.parse(response.body).first
      expect(entry['issues']).to eq([])
    end

    it 'flags wrong_group and ticket_not_in_group' do
      wrong_group = vehicle(plate: 'SAA 2009', form: support_form, base: expedition_member)
      crew(vehicle: wrong_group, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      not_in_group = vehicle(plate: 'SAA 2010', form: expedition_form, base: expedition_member)
      crew(vehicle: not_in_group, ticket_type: expedition_member, name: 'Driver Two', role: 'Driver')
      crew(vehicle: not_in_group, ticket_type: support_additional_member, name: 'Stray Passenger')

      get "/v1/events/#{event.id}/vehicle_registrations", headers: headers

      body = JSON.parse(response.body)
      by_plate = body.index_by { |car| car['plate'] }
      expect(by_plate['SAA 2009']['issues'].map { |i| i['code'] }).to include('wrong_group')
      expect(by_plate['SAA 2010']['issues'].map { |i| i['code'] }).to include('ticket_not_in_group')
    end

    it 'requires authentication' do
      get "/v1/events/#{event.id}/vehicle_registrations"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids users without access to the event, even when it is public' do
      event.update!(published: true, visibility: true)
      outsider = create(:user, :member)
      outsider_token = JwtService.generate_tokens(outsider)[:access_token]

      get "/v1/events/#{event.id}/vehicle_registrations",
          headers: { 'Authorization' => "Bearer #{outsider_token}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/events/:event_id/vehicle_registrations/:id/move_group' do
    it 'moves a solo car to another group' do
      car = vehicle(plate: 'SAA 3000', form: support_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/move_group",
            params: { registration_form_id: expedition_form.id }, headers: headers

      expect(response).to have_http_status(:ok)
      car.reload
      expect(car.registration_form_id).to eq(expedition_form.id)
      expect(car.base_ticket_type_id).to eq(expedition_member.id)
      expect(JSON.parse(response.body)['issues']).to eq([])
    end

    it 'refuses to move a car with crew' do
      car = vehicle(plate: 'SAA 3001', form: support_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      crew(vehicle: car, ticket_type: additional_member, name: 'Passenger One')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/move_group",
            params: { registration_form_id: expedition_form.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors'].first).to match(/has other crew/)
      expect(car.reload.registration_form_id).to eq(support_form.id)
    end

    it 'refuses when the mover holds the wrong ticket type for the target group' do
      car = vehicle(plate: 'SAA 3002', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: additional_member, name: 'Only Passenger')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/move_group",
            params: { registration_form_id: support_form.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors'].first).to match(/main vehicle ticket type/)
    end

    it 'refuses an invalid target group' do
      plain_form = create(:registration_form, event: event, slug: 'conference', name: 'Conference')
      car = vehicle(plate: 'SAA 3003', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/move_group",
            params: { registration_form_id: plain_form.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors'].first).to match(/valid vehicle group/)
    end

    it 'returns 404 when the event does not have vehicles enabled' do
      event.update!(vehicles_enabled: false)
      car = vehicle(plate: 'SAA 3004', form: expedition_form, base: expedition_member)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/move_group",
            params: { registration_form_id: expedition_b_form.id }, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'forbids users who cannot update tickets' do
      outsider = create(:user, :member)
      outsider_token = JwtService.generate_tokens(outsider)[:access_token]
      car = vehicle(plate: 'SAA 3005', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/move_group",
            params: { registration_form_id: expedition_b_form.id },
            headers: { 'Authorization' => "Bearer #{outsider_token}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/events/:event_id/vehicle_registrations/:id/sync_base' do
    it 'sets the base ticket type to the one the crew holds' do
      car = vehicle(plate: 'SAA 4000', form: expedition_form, base: expedition_b_member)
      holder = crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/sync_base", headers: headers

      expect(response).to have_http_status(:ok)
      expect(car.reload.base_ticket_type_id).to eq(expedition_member.id)
      expect(JSON.parse(response.body)['issues']).to eq([])
      expect(JSON.parse(response.body)['crew'].first['ticket_id']).to eq(holder.id)
    end

    it 'refuses when no crew member holds a base ticket' do
      car = vehicle(plate: 'SAA 4001', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: additional_member, name: 'Only Passenger')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/sync_base", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors'].first).to match(/No crew member/)
    end

    it 'refuses when more than one crew member holds a base ticket' do
      car = vehicle(plate: 'SAA 4002', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      crew(vehicle: car, ticket_type: expedition_b_member, name: 'Passenger One')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/sync_base", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors'].first).to match(/More than one/)
    end

    it 'returns 404 when the event does not have vehicles enabled' do
      event.update!(vehicles_enabled: false)
      car = vehicle(plate: 'SAA 4003', form: expedition_form, base: expedition_member)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/sync_base", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'forbids users who cannot update tickets' do
      outsider = create(:user, :member)
      outsider_token = JwtService.generate_tokens(outsider)[:access_token]
      car = vehicle(plate: 'SAA 4004', form: expedition_form, base: expedition_b_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/sync_base",
            headers: { 'Authorization' => "Bearer #{outsider_token}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET archived filtering' do
    it 'lists only active vehicles by default and archived ones on demand' do
      active_car = vehicle(plate: 'SAA 5000', form: expedition_form, base: expedition_member)
      archived_car = vehicle(plate: 'SAA 5001', form: expedition_form, base: expedition_member)
      archived_car.update!(deleted_at: Time.current)

      get "/v1/events/#{event.id}/vehicle_registrations", headers: headers
      expect(JSON.parse(response.body).map { |c| c['plate'] }).to eq([active_car.plate])

      get "/v1/events/#{event.id}/vehicle_registrations", params: { archived: 'true' }, headers: headers
      expect(JSON.parse(response.body).map { |c| c['plate'] }).to eq([archived_car.plate])

      get "/v1/events/#{event.id}/vehicle_registrations", params: { archived: 'all' }, headers: headers
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe 'PATCH /v1/events/:event_id/vehicle_registrations/:id' do
    it 'renames the plate and syncs crew tickets custom field' do
      car = vehicle(plate: 'SAA 6000', form: expedition_form, base: expedition_member)
      member = crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')
      member.update!(custom_fields_data: { 'car_registration_number' => 'SAA6000' })

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}",
            params: { plate: 'saa-6000 x' }, headers: headers

      expect(response).to have_http_status(:ok)
      car.reload
      expect(car.plate).to eq('SAA6000X')
      expect(car.normalized_plate).to eq('SAA6000X')
      expect(member.reload.custom_fields_data['car_registration_number']).to eq('SAA6000X')
      expect(JSON.parse(response.body)['plate']).to eq('SAA6000X')
    end

    it 'rejects a blank plate' do
      car = vehicle(plate: 'SAA 6001', form: expedition_form, base: expedition_member)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}",
            params: { plate: '  ' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(car.reload.plate).to eq('SAA 6001')
    end

    it 'rejects a plate taken by another active vehicle in the event' do
      vehicle(plate: 'SAA 6002', form: expedition_form, base: expedition_member)
      car = vehicle(plate: 'SAA 6003', form: expedition_form, base: expedition_member)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}",
            params: { plate: 'SAA6002' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(car.reload.plate).to eq('SAA 6003')
    end

    it 'allows renaming to a plate that belongs to an archived vehicle' do
      old = vehicle(plate: 'SAA6004', form: expedition_form, base: expedition_member)
      old.update!(deleted_at: Time.current)
      car = vehicle(plate: 'SAA 6005', form: expedition_form, base: expedition_member)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}",
            params: { plate: 'SAA6004' }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(car.reload.normalized_plate).to eq('SAA6004')
    end

    it 'refuses to rename an archived vehicle' do
      car = vehicle(plate: 'SAA 6006', form: expedition_form, base: expedition_member)
      car.update!(deleted_at: Time.current)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}",
            params: { plate: 'SAA6007' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(car.reload.plate).to eq('SAA 6006')
    end
  end

  describe 'PATCH /v1/events/:event_id/vehicle_registrations/:id/archive' do
    it 'archives and restores a vehicle without active crew' do
      car = vehicle(plate: 'SAA 7000', form: expedition_form, base: expedition_member)
      member = crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver', status: :canceled)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/archive", headers: headers

      expect(response).to have_http_status(:ok)
      expect(car.reload.archived?).to be(true)
      # Inactive tickets stay attached — archiving hides the row, it doesn't detach.
      expect(member.reload.vehicle_registration_id).to eq(car.id)

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/restore", headers: headers

      expect(response).to have_http_status(:ok)
      expect(car.reload.archived?).to be(false)
    end

    it 'refuses to archive a vehicle with active crew' do
      car = vehicle(plate: 'SAA 7002', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      patch "/v1/events/#{event.id}/vehicle_registrations/#{car.id}/archive", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('1 active crew')
      expect(car.reload.archived?).to be(false)
    end

    it 'frees the plate for a new registration while archived' do
      car = vehicle(plate: 'SAA7001', form: expedition_form, base: expedition_member)
      car.update!(deleted_at: Time.current)

      fresh = VehicleRegistration.new(
        event: event,
        registration_form: expedition_form,
        base_ticket_type: expedition_member,
        plate: 'SAA7001',
        normalized_plate: 'SAA7001'
      )

      expect(fresh).to be_valid
    end
  end

  describe 'DELETE /v1/events/:event_id/vehicle_registrations/:id' do
    it 'deletes the vehicle and detaches inactive crew tickets' do
      car = vehicle(plate: 'SAA 8000', form: expedition_form, base: expedition_member)
      member = crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver', status: :refunded)

      delete "/v1/events/#{event.id}/vehicle_registrations/#{car.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(VehicleRegistration.exists?(car.id)).to be(false)
      expect(member.reload.vehicle_registration_id).to be_nil
    end

    it 'refuses to delete a vehicle with active crew' do
      car = vehicle(plate: 'SAA 8002', form: expedition_form, base: expedition_member)
      crew(vehicle: car, ticket_type: expedition_member, name: 'Driver One', role: 'Driver')

      delete "/v1/events/#{event.id}/vehicle_registrations/#{car.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(VehicleRegistration.exists?(car.id)).to be(true)
    end

    it 'is forbidden for non-owner organizers' do
      organizer = create(:user, :organizer)
      organizer_token = JwtService.generate_tokens(organizer)[:access_token]
      car = vehicle(plate: 'SAA 8001', form: expedition_form, base: expedition_member)

      delete "/v1/events/#{event.id}/vehicle_registrations/#{car.id}",
             headers: { 'Authorization' => "Bearer #{organizer_token}" }

      expect(response).to have_http_status(:forbidden)
      expect(VehicleRegistration.exists?(car.id)).to be(true)
    end
  end
end
