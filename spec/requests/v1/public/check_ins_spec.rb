# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::Public::CheckIns', type: :request do
  # ============================================
  # Ticket-based event tests
  # ============================================
  describe 'Ticket-based event' do
    let(:event) { create(:event, use_ticket: true) }
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

    let(:other_event) { create(:event, use_ticket: true) }
    let(:other_ticket_type) { create(:ticket_type, event: other_event) }
    let!(:other_event_ticket) do
      create(:ticket, :paid,
             event: other_event,
             ticket_type: other_ticket_type,
             attendee_name: 'Other Event User',
             attendee_email: 'other@example.com')
    end

    describe 'GET /v1/public/events/:event_slug/check_in' do
      let(:endpoint) { "/v1/public/events/#{event.slug}/check_in" }

      it 'returns event info' do
        get endpoint

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['id']).to eq(event.id)
        expect(data['title']).to eq(event.title)
        expect(data['slug']).to eq(event.slug)
        expect(data['use_ticket']).to eq(true)
      end

      it 'returns 404 for non-existent event' do
        get '/v1/public/events/non-existent-event/check_in'

        expect(response).to have_http_status(:not_found)
        expect(json_response['message']).to eq('Event not found')
      end
    end

    describe 'POST /v1/public/events/:event_slug/check_in' do
      let(:endpoint) { "/v1/public/events/#{event.slug}/check_in" }

      context 'with invalid parameters' do
        it 'returns error when method is missing' do
          post endpoint, params: { value: 'test' }

          expect(response).to have_http_status(:bad_request)
          expect(json_response['message']).to include('Invalid method')
        end

        it 'returns error when method is invalid' do
          post endpoint, params: { method: 'invalid', value: 'test' }

          expect(response).to have_http_status(:bad_request)
          expect(json_response['message']).to include('Invalid method')
        end

        it 'returns error when value is missing' do
          post endpoint, params: { method: 'name' }

          expect(response).to have_http_status(:bad_request)
          expect(json_response['message']).to eq('Value is required')
        end

        it 'returns error when value is blank' do
          post endpoint, params: { method: 'name', value: '   ' }

          expect(response).to have_http_status(:bad_request)
          expect(json_response['message']).to eq('Value is required')
        end
      end

      context 'with invalid event slug' do
        it 'returns 404 for non-existent event' do
          post '/v1/public/events/non-existent-event/check_in',
               params: { method: 'name', value: 'John' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Event not found')
        end
      end

      context 'search by name' do
        it 'returns matching attendees' do
          post endpoint, params: { method: 'name', value: 'John' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('select')
          expect(data['attendees'].length).to eq(2)

          attendee = data['attendees'].find { |a| a['name'] == 'John Doe' }
          expect(attendee['public_id']).to eq(paid_ticket.public_id)
          expect(attendee['email']).to eq('john.doe@example.com')
          expect(attendee['phone']).to eq('+60123456789')
          expect(attendee['type_name']).to eq(ticket_type.name)
          expect(attendee['checked_in']).to eq(false)
        end

        it 'returns 404 when no attendees match' do
          post endpoint, params: { method: 'name', value: 'NonExistent' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end

        it 'returns unpaid tickets' do
          post endpoint, params: { method: 'name', value: 'Jane Unpaid' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('select')
          expect(data['attendees'].length).to eq(1)
          expect(data['attendees'][0]['name']).to eq('Jane Unpaid')
        end

        it 'does not return tickets from other events' do
          post endpoint, params: { method: 'name', value: 'Other Event User' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end
      end

      context 'search by email' do
        it 'returns matching attendee' do
          post endpoint, params: { method: 'email', value: 'john.doe@example.com' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('select')
          expect(data['attendees'].length).to eq(1)
          expect(data['attendees'][0]['public_id']).to eq(paid_ticket.public_id)
        end

        it 'is case insensitive' do
          post endpoint, params: { method: 'email', value: 'JOHN.DOE@EXAMPLE.COM' }

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attendees'].length).to eq(1)
        end

        it 'returns 404 when no attendees match' do
          post endpoint, params: { method: 'email', value: 'nonexistent@example.com' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end
      end

      context 'search by phone' do
        it 'returns matching attendee' do
          post endpoint, params: { method: 'phone', value: '+60123456789' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('select')
          expect(data['attendees'].length).to eq(1)
          expect(data['attendees'][0]['public_id']).to eq(paid_ticket.public_id)
        end

        it 'normalizes phone numbers for comparison' do
          post endpoint, params: { method: 'phone', value: '60-123-456-789' }

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attendees'].length).to eq(1)
        end

        it 'returns 404 when no attendees match' do
          post endpoint, params: { method: 'phone', value: '+60000000000' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end
      end

      context 'check-in by scan (public_id)' do
        it 'successfully checks in a ticket' do
          post endpoint, params: { method: 'scan', value: paid_ticket.public_id }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('checked_in')
          expect(data['message']).to eq('Successfully checked in.')
          expect(data['attendee']['public_id']).to eq(paid_ticket.public_id)
          expect(data['attendee']['checked_in']).to eq(true)
          expect(data['attendee']['check_in_at']).to be_present

          paid_ticket.reload
          expect(paid_ticket.checked_in).to eq(true)
          expect(paid_ticket.status).to eq('scanned')
        end

        it 'returns error for already checked-in ticket' do
          paid_ticket.update!(checked_in: true, check_in_at: Time.current, status: :scanned)

          post endpoint, params: { method: 'scan', value: paid_ticket.public_id }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['message']).to eq('Already checked in')
          expect(json_response['errors']['check_in_at']).to be_present
        end

        it 'returns 404 for non-existent public_id' do
          post endpoint, params: { method: 'scan', value: 'non-existent-uuid' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end

        it 'returns 404 for ticket from different event' do
          post endpoint, params: { method: 'scan', value: other_event_ticket.public_id }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end

        it 'successfully checks in unpaid ticket' do
          post endpoint, params: { method: 'scan', value: unpaid_ticket.public_id }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('checked_in')
          expect(data['attendee']['public_id']).to eq(unpaid_ticket.public_id)

          unpaid_ticket.reload
          expect(unpaid_ticket.checked_in).to eq(true)
        end

        context 'with check_in_url parameter' do
          it 'stores check_in_url for webhook integration' do
            check_in_url = 'https://example.com/events/test/check-in?station=1'

            post endpoint, params: {
              method: 'scan',
              value: paid_ticket.public_id,
              check_in_url: check_in_url
            }

            expect(response).to have_http_status(:ok)
            expect(json_response['data']['action']).to eq('checked_in')

            paid_ticket.reload
            expect(paid_ticket.checked_in).to eq(true)
          end
        end
      end
    end
  end

  # ============================================
  # Visitor-based event tests
  # ============================================
  describe 'Visitor-based event' do
    let(:event) { create(:event, use_ticket: false) }

    let!(:visitor) do
      create(:visitor,
             event: event,
             full_name: 'Alice Visitor',
             email: 'alice@example.com',
             phone: '+60111222333')
    end

    let!(:another_visitor) do
      create(:visitor,
             event: event,
             full_name: 'Alice Wong',
             email: 'alice.wong@example.com',
             phone: '+60444555666')
    end

    let(:other_event) { create(:event, use_ticket: false) }
    let!(:other_event_visitor) do
      create(:visitor,
             event: other_event,
             full_name: 'Other Visitor',
             email: 'other.visitor@example.com')
    end

    describe 'GET /v1/public/events/:event_slug/check_in' do
      let(:endpoint) { "/v1/public/events/#{event.slug}/check_in" }

      it 'returns event info with use_ticket false' do
        get endpoint

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['use_ticket']).to eq(false)
      end
    end

    describe 'POST /v1/public/events/:event_slug/check_in' do
      let(:endpoint) { "/v1/public/events/#{event.slug}/check_in" }

      context 'search by name' do
        it 'returns matching visitors' do
          post endpoint, params: { method: 'name', value: 'Alice' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('select')
          expect(data['attendees'].length).to eq(2)

          attendee = data['attendees'].find { |a| a['name'] == 'Alice Visitor' }
          expect(attendee['public_id']).to eq(visitor.public_id)
          expect(attendee['email']).to eq('alice@example.com')
        end

        it 'returns 404 when no visitors match from other events' do
          post endpoint, params: { method: 'name', value: 'Other Visitor' }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end
      end

      context 'search by email' do
        it 'returns matching visitor' do
          post endpoint, params: { method: 'email', value: 'alice@example.com' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['attendees'].length).to eq(1)
          expect(data['attendees'][0]['public_id']).to eq(visitor.public_id)
        end
      end

      context 'search by phone' do
        it 'returns matching visitor' do
          post endpoint, params: { method: 'phone', value: '+60111222333' }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['attendees'].length).to eq(1)
          expect(data['attendees'][0]['public_id']).to eq(visitor.public_id)
        end
      end

      context 'check-in by scan (public_id)' do
        it 'successfully checks in a visitor' do
          post endpoint, params: { method: 'scan', value: visitor.public_id }

          expect(response).to have_http_status(:ok)
          data = json_response['data']
          expect(data['action']).to eq('checked_in')
          expect(data['attendee']['public_id']).to eq(visitor.public_id)
          expect(data['attendee']['checked_in']).to eq(true)

          visitor.reload
          expect(visitor.checked_in).to eq(true)
        end

        it 'returns error for already checked-in visitor' do
          visitor.update!(checked_in: true, check_in_at: Time.current)

          post endpoint, params: { method: 'scan', value: visitor.public_id }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['message']).to eq('Already checked in')
        end

        it 'returns 404 for visitor from different event' do
          post endpoint, params: { method: 'scan', value: other_event_visitor.public_id }

          expect(response).to have_http_status(:not_found)
          expect(json_response['message']).to eq('Resource not found')
        end

        context 'with check_in_url parameter' do
          it 'stores check_in_url for webhook integration' do
            check_in_url = 'https://example.com/events/test/check-in?station=2'

            post endpoint, params: {
              method: 'scan',
              value: visitor.public_id,
              check_in_url: check_in_url
            }

            expect(response).to have_http_status(:ok)
            expect(json_response['data']['action']).to eq('checked_in')

            visitor.reload
            expect(visitor.checked_in).to eq(true)
          end
        end
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
