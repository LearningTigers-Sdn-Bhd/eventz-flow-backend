# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::Public::CheckIns', type: :request do
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }

  let!(:paid_ticket) do
    create(:ticket, :paid,
           event: event,
           ticket_type: ticket_type,
           attendee_name: 'John Doe',
           attendee_email: 'john.doe@example.com',
           attendee_phone: '+60123456789')
  end

  let!(:another_paid_ticket) do
    create(:ticket, :paid,
           event: event,
           ticket_type: ticket_type,
           attendee_name: 'John Smith',
           attendee_email: 'john.smith@example.com',
           attendee_phone: '+60198765432')
  end

  let!(:unpaid_ticket) do
    create(:ticket,
           event: event,
           ticket_type: ticket_type,
           attendee_name: 'Jane Unpaid',
           attendee_email: 'jane.unpaid@example.com',
           payment_status: :pending)
  end

  let(:other_event) { create(:event) }
  let(:other_ticket_type) { create(:ticket_type, event: other_event) }
  let!(:other_event_ticket) do
    create(:ticket, :paid,
           event: other_event,
           ticket_type: other_ticket_type,
           attendee_name: 'Other Event User',
           attendee_email: 'other@example.com')
  end

  describe 'POST /v1/public/events/:event_slug/check_in' do
    let(:endpoint) { "/v1/public/events/#{event.slug}/check_in" }

    context 'with invalid parameters' do
      it 'returns error when method is missing' do
        post endpoint, params: { value: 'test' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to include('Invalid method')
      end

      it 'returns error when method is invalid' do
        post endpoint, params: { method: 'invalid', value: 'test' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to include('Invalid method')
      end

      it 'returns error when value is missing' do
        post endpoint, params: { method: 'name' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Value is required')
      end

      it 'returns error when value is blank' do
        post endpoint, params: { method: 'name', value: '   ' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Value is required')
      end
    end

    context 'with invalid event slug' do
      it 'returns 404 for non-existent event' do
        post '/v1/public/events/non-existent-event/check_in',
             params: { method: 'name', value: 'John' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Event not found')
      end
    end

    context 'search by name' do
      it 'returns matching tickets with masked data' do
        post endpoint, params: { method: 'name', value: 'John' }

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['action']).to eq('select')
        expect(data['tickets'].length).to eq(2)

        ticket = data['tickets'].find { |t| t['attendee_name'] == 'John Doe' }
        expect(ticket['public_id']).to eq(paid_ticket.public_id)
        expect(ticket['attendee_email']).to match(/j\*\*\*.*@example\.com/)
        expect(ticket['attendee_phone']).to match(/\*\*\*-\*\*\*-\d{4}/)
        expect(ticket['role']).to be_present
        expect(ticket['ticket_type']['name']).to eq(ticket_type.name)
        expect(ticket['checked_in']).to eq(false)
      end

      it 'returns 404 when no tickets match' do
        post endpoint, params: { method: 'name', value: 'NonExistent' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('No tickets found')
      end

      it 'does not return unpaid tickets' do
        post endpoint, params: { method: 'name', value: 'Jane Unpaid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('No tickets found')
      end

      it 'does not return tickets from other events' do
        post endpoint, params: { method: 'name', value: 'Other Event User' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('No tickets found')
      end
    end

    context 'search by email' do
      it 'returns matching ticket with masked data' do
        post endpoint, params: { method: 'email', value: 'john.doe@example.com' }

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['action']).to eq('select')
        expect(data['tickets'].length).to eq(1)
        expect(data['tickets'][0]['public_id']).to eq(paid_ticket.public_id)
        expect(data['tickets'][0]['attendee_email']).to match(/j\*\*\*.*@example\.com/)
      end

      it 'is case insensitive' do
        post endpoint, params: { method: 'email', value: 'JOHN.DOE@EXAMPLE.COM' }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['tickets'].length).to eq(1)
      end

      it 'returns 404 when no tickets match' do
        post endpoint, params: { method: 'email', value: 'nonexistent@example.com' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'search by phone' do
      it 'returns matching ticket with masked data' do
        post endpoint, params: { method: 'phone', value: '+60123456789' }

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['action']).to eq('select')
        expect(data['tickets'].length).to eq(1)
        expect(data['tickets'][0]['public_id']).to eq(paid_ticket.public_id)
      end

      it 'normalizes phone numbers for comparison' do
        post endpoint, params: { method: 'phone', value: '60-123-456-789' }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['tickets'].length).to eq(1)
      end

      it 'returns 404 when no tickets match' do
        post endpoint, params: { method: 'phone', value: '+60000000000' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'check-in by scan (public_id)' do
      it 'successfully checks in a ticket' do
        post endpoint, params: { method: 'scan', value: paid_ticket.public_id }

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['action']).to eq('checked_in')
        expect(data['message']).to eq('Successfully checked in.')
        expect(data['ticket']['public_id']).to eq(paid_ticket.public_id)
        expect(data['ticket']['checked_in']).to eq(true)
        expect(data['ticket']['check_in_at']).to be_present
        # Full data shown after check-in
        expect(data['ticket']['attendee_email']).to eq('john.doe@example.com')
        expect(data['ticket']['attendee_phone']).to eq('+60123456789')

        paid_ticket.reload
        expect(paid_ticket.checked_in).to eq(true)
        expect(paid_ticket.status).to eq('scanned')
      end

      it 'returns error for already checked-in ticket' do
        paid_ticket.update!(checked_in: true, check_in_at: Time.current, status: :scanned)

        post endpoint, params: { method: 'scan', value: paid_ticket.public_id }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq('Ticket already checked in')
        expect(json_response['errors']['check_in_at']).to be_present
      end

      it 'returns 404 for non-existent public_id' do
        post endpoint, params: { method: 'scan', value: 'non-existent-uuid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Ticket not found')
      end

      it 'returns 404 for ticket from different event (prevents data leakage)' do
        post endpoint, params: { method: 'scan', value: other_event_ticket.public_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Ticket not found')
      end

      it 'returns 404 for unpaid ticket' do
        post endpoint, params: { method: 'scan', value: unpaid_ticket.public_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Ticket not found')
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
