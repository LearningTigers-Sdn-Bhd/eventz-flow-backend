require 'rails_helper'

RSpec.describe SeatTicketing::CheckoutService do
  let(:event) { create(:event, use_seat_ticketing: true, use_ticket: true) }
  let!(:ticket_type) { create(:ticket_type, event: event, price: 100) }
  let(:session) { create(:event_seat_session, event: event, status: :published) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue) }
  let!(:seats) do
    [
      create(:event_ticket_seat, event_seat_section: section, row_set: 1, col_set: 1),
      create(:event_ticket_seat, event_seat_section: section, row_set: 1, col_set: 2)
    ]
  end
  let!(:checkout_session) { create(:event_seat_checkout_session, event_seat_session: session) }

  let(:params) do
    ActionController::Parameters.new({
      visitor: {
        full_name: 'John Doe',
        email: 'john@example.com',
        phone: '123456789'
      },
      seat_ids: seats.map(&:id),
      checkout_session_uuid: checkout_session.id,
      ticket_type_id: ticket_type.id
    })
  end

  subject { described_class.new(session, params) }

  describe '#call' do
    context 'with valid parameters' do
      it 'successfully processes checkout' do
        expect { subject.call }.to change(Ticket, :count).by(1)
                               .and change(Visitor, :count).by(1)
                               .and change(EventSeatCheckoutSession, :count).by(-1)

        expect(subject.errors).to be_empty
        expect(subject.result[:success]).to be true
        
        # Verify seats updated
        seats.each do |seat|
          expect(seat.reload.visitor_id).to eq(subject.result[:visitor].id)
          expect(seat.reload.ticket_id).to eq(subject.result[:ticket]['id'])
        end
      end

      it 'updates existing visitor if email matches' do
        visitor = create(:visitor, event: event, email: 'john@example.com')
        expect { subject.call }.to change(Visitor, :count).by(0)
        expect(subject.result[:visitor].id).to eq(visitor.id)
      end
    end

    context 'with invalid parameters' do
      it 'fails if visitor email is missing' do
        params[:visitor][:email] = nil
        expect(subject.call).to be false
        expect(subject.errors).to include('Visitor email is required')
      end

      it 'fails if checkout_session_uuid is missing' do
        params[:checkout_session_uuid] = nil
        expect(subject.call).to be false
        expect(subject.errors).to include('checkout_session_uuid is required')
      end

      it 'fails if checkout session is expired' do
        checkout_session.update(created_at: 1.hour.ago)
        expect(subject.call).to be false
        expect(subject.errors).to include('Checkout session expired')
      end

      it 'fails if seats are already taken' do
        # If event.use_ticket is true, 'sold' depends on ticket_id
        seats.first.update(ticket_id: create(:ticket).id)
        expect(subject.call).to be false
        expect(subject.errors.first).to include('Some seats are no longer available')
      end

      it 'fails if seats belong to another session' do
        other_session = create(:event_seat_session, event: event)
        other_venue = create(:event_seat_venue, event_seat_session: other_session)
        other_section = create(:event_seat_section, event_seat_venue: other_venue)
        other_seat = create(:event_ticket_seat, event_seat_section: other_section)
        
        params[:seat_ids] = [other_seat.id]
        expect(subject.call).to be false
        expect(subject.errors).to include('Some seats were not found')
      end
    end

    context 'transactional integrity' do
      it 'does not create ticket or visitor if seat update fails' do
        # Force a failure during seat update by making a validation fail
        # For example, name can't be blank
        allow_any_instance_of(EventTicketSeat).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(seats.first))

        expect { subject.call }.to change(Ticket, :count).by(0)
                               .and change(Visitor, :count).by(0)
        
        expect(subject.errors).not_to be_empty
      end
    end
  end
end
