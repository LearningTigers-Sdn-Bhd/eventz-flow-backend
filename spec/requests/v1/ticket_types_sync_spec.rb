require 'rails_helper'

RSpec.describe 'V1::TicketTypes Sync', type: :request do
  let(:event_admin) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }
  let(:headers) { { 'Authorization' => "Bearer #{event_admin_token}" } }

  let(:event) { create(:event, use_seat_ticketing: true, use_ticket: true) }
  let!(:assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  let(:session) { create(:event_seat_session, event: event, location: nil) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue, price: 100.0) }

  before do
    SeatTicketing::SyncService.sync_section(section)
  end

  describe 'DELETE /v1/events/:event_id/ticket_types/:id' do
    let(:ticket_type) { section.reload.ticket_type }

    it 'blocks deletion of section base ticket type' do
      delete "/v1/events/#{event.id}/ticket_types/#{ticket_type.id}", headers: headers
      
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('Cannot delete the base ticket type')
    end

    it 'allows deletion of group ticket type and destroys the group' do
      group = create(:event_seat_group, event_seat_section: section)
      SeatTicketing::SyncService.sync_group(group)
      group_ticket = group.reload.ticket_type

      delete "/v1/events/#{event.id}/ticket_types/#{group_ticket.id}", headers: headers
      
      expect(response).to have_http_status(:no_content)
      expect(EventSeatGroup.find_by(id: group.id)).to be_nil
    end

    it 'allows deletion of individual ticket type and resets seat extra_price' do
      seat = create(:event_ticket_seat, event_seat_section: section, extra_price: 50.0)
      SeatTicketing::SyncService.sync_seat(seat)
      seat_ticket = seat.reload.ticket_type

      delete "/v1/events/#{event.id}/ticket_types/#{seat_ticket.id}", headers: headers
      
      expect(response).to have_http_status(:no_content)
      expect(seat.reload.extra_price).to eq(0)
    end
  end

  describe 'PATCH /v1/events/:event_id/ticket_types/:id' do
    let(:ticket_type) { section.reload.ticket_type }

    it 'syncs price changes back to the map section' do
      patch "/v1/events/#{event.id}/ticket_types/#{ticket_type.id}", 
            params: { ticket_type: { price: 150.0 } }, headers: headers
      
      expect(response).to have_http_status(:ok)
      expect(section.reload.price).to eq(150.0)
    end
  end
end
