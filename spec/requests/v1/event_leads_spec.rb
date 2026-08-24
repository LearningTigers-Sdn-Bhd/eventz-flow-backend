# spec/requests/v1/event_leads_spec.rb
require 'rails_helper'

RSpec.describe 'V1::EventLeads', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:vendor_user) { create(:user, role: :vendor) }
  let(:other_vendor) { create(:user, role: :vendor) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }
  let(:other_vendor_token) { JwtService.generate_tokens(other_vendor)[:access_token] }

  # --- Setup Event ---
  let!(:event) do
    create(:event, title: 'Test Event', payment_status: :paid, use_ticket: false, use_event_leads: true)
  end
  let!(:other_event) do
    create(:event, title: 'Other Event', payment_status: :paid, use_ticket: true, use_event_leads: true)
  end

  # --- Setup Event Vendors ---
  let!(:event_vendor) do
    create(:event_vendor, event: event, vendor: vendor_user, redirect_url: 'https://example.com')
  end

  let!(:other_event_vendor) do
    create(:event_vendor, event: event, vendor: other_vendor, redirect_url: 'https://example.com')
  end

  # --- Setup Visitors ---
  let!(:visitor) do
    create(:visitor, event: event, full_name: 'Test Visitor', email: 'visitor@example.com', phone: '+1234567890')
  end

  let!(:visitor2) do
    create(:visitor, event: event, full_name: 'Second Visitor', email: 'visitor2@example.com', phone: '+0987654321')
  end

  # --- Setup Tickets ---
  let!(:ticket) do
    create(:ticket, event: event, attendee_name: 'Ticket Attendee', attendee_email: 'ticket@example.com', attendee_phone: '+1112223333')
  end
  let!(:other_event_ticket) do
    create(:ticket, event: other_event, attendee_name: 'Other Event Attendee')
  end

  # --- Setup Leads ---
  let!(:vendor_lead) do
    create(:event_lead, leadable: visitor, event_vendor: event_vendor)
  end

  let!(:other_vendor_lead) do
    create(:event_lead, leadable: visitor2, event_vendor: other_event_vendor)
  end

  describe 'GET /v1/events/:event_id/event-leads' do
    context 'when user is org_owner' do
      it 'returns all leads for the event' do
        get "/v1/events/#{event.id}/event-leads", headers: { 'Authorization' => "Bearer #{org_owner_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data.length).to eq(2)
      end
    end

    context 'when user is organizer' do
      it 'returns all leads for the event' do
        get "/v1/events/#{event.id}/event-leads", headers: { 'Authorization' => "Bearer #{organizer_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data.length).to eq(2)
      end
    end

    context 'when user is a vendor' do
      it 'returns only their own leads' do
        get "/v1/events/#{event.id}/event-leads", headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data.length).to eq(1)
        expect(data[0]['vendor_name']).to eq(vendor_user.full_name)
      end

      it 'does not return other vendors leads' do
        get "/v1/events/#{event.id}/event-leads", headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        vendor_names = data.map { |lead| lead['vendor_name'] }
        expect(vendor_names).not_to include(other_vendor.full_name)
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get "/v1/events/#{event.id}/event-leads"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when event does not exist' do
      it 'returns 404 not found' do
        get "/v1/events/99999/event-leads", headers: { 'Authorization' => "Bearer #{vendor_token}" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /v1/events/:event_id/event-leads' do
    context 'when vendor scans a visitor' do
      it 'creates a lead successfully' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')

        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: new_visitor.public_id, event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['leadable_type']).to eq('Visitor')
        expect(data['leadable_id']).to eq(new_visitor.id)
        expect(data['event_vendor_id']).to eq(event_vendor.id)
      end

      it 'returns existing lead if already captured' do
        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: visitor.public_id, event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['id']).to eq(vendor_lead.id)
      end
    end

    context 'when vendor scans a ticket' do
      it 'creates a lead successfully from a ticket' do
        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: ticket.public_id, event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['leadable_type']).to eq('Ticket')
        expect(data['leadable_id']).to eq(ticket.id)
      end
    end

    context 'when vendor creates lead with notes' do
      it 'saves the notes' do
        new_visitor = create(:visitor, event: event, full_name: 'Notes Visitor')

        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: new_visitor.public_id, event_vendor_id: event_vendor.id, notes: 'Interested in partnership' },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['notes']).to eq('Interested in partnership')
      end
    end

    context 'when vendor tries to create lead for another vendor' do
      it 'returns 403 forbidden' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')

        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: new_visitor.public_id, event_vendor_id: other_event_vendor.id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when org_owner creates lead' do
      it 'can create lead for any vendor' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')

        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: new_visitor.public_id, event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{org_owner_token}" }

        expect(response).to have_http_status(:created)
      end
    end

    context 'when organizer creates lead' do
      it 'can create lead for any vendor' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')

        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: new_visitor.public_id, event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{organizer_token}" }

        expect(response).to have_http_status(:created)
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: visitor.public_id, event_vendor_id: event_vendor.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid parameters' do
      it 'returns 404 if attendee not found' do
        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: 'non-existent-id', event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 400 if public_id is missing' do
        post "/v1/events/#{event.id}/event-leads",
             params: { event_vendor_id: event_vendor.id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns 400 if event_vendor_id is missing' do
        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: visitor.public_id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns 404 if event_vendor not found' do
        post "/v1/events/#{event.id}/event-leads",
             params: { public_id: visitor.public_id, event_vendor_id: 99999 },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /v1/events/:event_id/event-leads/:id' do
    context 'when vendor updates notes' do
      it 'updates the notes successfully' do
        patch "/v1/events/#{event.id}/event-leads/#{vendor_lead.id}",
              params: { notes: 'Updated notes - very interested' },
              headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['notes']).to eq('Updated notes - very interested')
      end
    end

    context 'when vendor tries to update another vendor lead' do
      it 'returns 403 forbidden' do
        patch "/v1/events/#{event.id}/event-leads/#{other_vendor_lead.id}",
              params: { notes: 'Hacking!' },
              headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        patch "/v1/events/#{event.id}/event-leads/#{vendor_lead.id}",
              params: { notes: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when lead does not exist' do
      it 'returns 404 not found' do
        patch "/v1/events/#{event.id}/event-leads/99999",
              params: { notes: 'test' },
              headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /v1/events/:event_id/event-leads/export' do
    context 'when user is org_owner' do
      it 'returns an xlsx file with all leads for the event' do
        get "/v1/events/#{event.id}/event-leads/export", headers: { 'Authorization' => "Bearer #{org_owner_token}" }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        expect(response.body).not_to be_empty
      end
    end

    context 'when user is a vendor' do
      it 'returns 200 with only their own leads' do
        get "/v1/events/#{event.id}/event-leads/export", headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get "/v1/events/#{event.id}/event-leads/export"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when event does not exist' do
      it 'returns 404 not found' do
        get "/v1/events/99999/event-leads/export", headers: { 'Authorization' => "Bearer #{vendor_token}" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /v1/event-leads/scan' do
    context 'when vendor is assigned to scanned ticket event' do
      it 'creates a lead successfully' do
        post '/v1/event-leads/scan',
             params: { public_id: ticket.public_id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['leadable_type']).to eq('Ticket')
        expect(data['leadable_id']).to eq(ticket.id)
      end
    end

    context 'when vendor is not assigned to scanned ticket event' do
      it 'returns forbidden with exact unauthorized message' do
        post '/v1/event-leads/scan',
             params: { public_id: other_event_ticket.public_id },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:forbidden)
        data = JSON.parse(response.body)
        expect(data['message']).to eq('You are not authorized to scan this ticket.')
      end
    end

    context 'when ticket does not exist' do
      it 'returns not found' do
        post '/v1/event-leads/scan',
             params: { public_id: 'missing-ticket' },
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
