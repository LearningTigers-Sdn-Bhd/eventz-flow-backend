require 'rails_helper'

RSpec.describe SeatTicketing::SyncService, type: :service do
  let(:event) { create(:event, use_seat_ticketing: true, use_ticket: true) }
  let(:session) { create(:event_seat_session, event: event, location: nil) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue, price: 100.0) }

  describe '.sync_section' do
    it 'creates a ticket type for the section' do
      expect {
        described_class.sync_section(section)
      }.to change(TicketType, :count).by(1)

      ticket_type = section.reload.ticket_type
      expect(ticket_type.name).to eq("#{session.name}: #{section.name}")
      expect(ticket_type.price).to eq(100.0)
      expect(ticket_type.seat_ticketing_type).to eq('st_section')
      expect(ticket_type.seat_ticketing_source_id).to eq(section.id)
    end

    it 'updates ticket type quantity based on standard seats' do
      create_list(:event_ticket_seat, 3, event_seat_section: section, extra_price: 0)
      described_class.sync_section(section)
      expect(section.reload.ticket_type.quantity).to eq(3)
    end
  end

  describe '.sync_group' do
    let(:group) { create(:event_seat_group, event_seat_section: section, extra_price: 50.0) }
    
    it 'creates a ticket type with section price + extra price' do
      create_list(:event_ticket_seat, 2, event_seat_section: section) do |seat|
        create(:event_seat_group_assignment, event_seat_group: group, event_ticket_seat: seat)
      end

      described_class.sync_group(group)
      
      ticket_type = group.reload.ticket_type
      expect(ticket_type.name).to eq("#{session.name}: #{section.name} - #{group.name}")
      expect(ticket_type.price).to eq(150.0) # 100 + 50
      expect(ticket_type.quantity).to eq(2)
      expect(ticket_type.seat_ticketing_type).to eq('st_group')
    end
  end

  describe '.sync_seat' do
    let(:seat) { create(:event_ticket_seat, event_seat_section: section, extra_price: 25.0) }

    it 'creates an individual ticket type for premium seat' do
      described_class.sync_seat(seat)
      
      ticket_type = seat.reload.ticket_type
      expect(ticket_type.name).to eq("#{session.name}: #{section.name} - #{seat.name}")
      expect(ticket_type.price).to eq(125.0) # 100 + 25
      expect(ticket_type.quantity).to eq(1)
      expect(ticket_type.seat_ticketing_type).to eq('st_individual')
    end
  end

  describe '.sync_from_ticket_type' do
    context 'when updating a section ticket' do
      it 'updates the section price' do
        described_class.sync_section(section)
        ticket_type = section.ticket_type
        
        ticket_type.update!(price: 120.0)
        described_class.sync_from_ticket_type(ticket_type)
        
        expect(section.reload.price).to eq(120.0)
      end
    end

    context 'when updating a group ticket' do
      let(:group) { create(:event_seat_group, event_seat_section: section, extra_price: 50.0) }
      
      it 'updates the group extra_price' do
        described_class.sync_group(group)
        ticket_type = group.ticket_type
        
        # New total price 180 (Section 100 + Extra 80)
        ticket_type.update!(price: 180.0)
        described_class.sync_from_ticket_type(ticket_type)
        
        expect(group.reload.extra_price).to eq(80.0)
      end
    end
  end

  describe 'model callbacks integration' do
    it 'automatically syncs when section price changes' do
      described_class.sync_section(section)
      ticket_type = section.ticket_type
      
      section.update!(price: 200.0)
      expect(ticket_type.reload.price).to eq(200.0)
    end

    it 'automatically syncs when group extra_price changes' do
      group = create(:event_seat_group, event_seat_section: section, extra_price: 10.0)
      ticket_type = group.reload.ticket_type
      
      group.update!(extra_price: 20.0)
      expect(ticket_type.reload.price).to eq(120.0)
    end
  end
end
