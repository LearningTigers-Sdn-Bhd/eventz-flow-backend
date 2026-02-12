require 'rails_helper'

RSpec.describe SeatTicketing::SeatGeneratorService do
  let(:event) { create(:event, use_seat_ticketing: true) }
  let(:session) { create(:event_seat_session, event: event) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue, seat_row: 2, seat_column: 2) }

  describe '.generate' do
    it 'generates a simple grid of seats' do
      expect {
        described_class.generate(section)
      }.to change(EventTicketSeat, :count).by(4)
      
      expect(section.event_ticket_seats.pluck(:name)).to contain_exactly(
        "#{section.name}-1A", "#{section.name}-1B",
        "#{section.name}-2A", "#{section.name}-2B"
      )
    end

    it 'handles row and column blocks with gaps' do
      config = {
        row_blocks: [1, 1],
        col_blocks: [1, 1],
        row_gap: 1,
        col_gap: 1
      }
      # Resulting coordinates should be: (1,1), (1,3), (3,1), (3,3)
      described_class.generate(section, config)
      
      expect(section.event_ticket_seats.pluck(:row_set, :col_set)).to contain_exactly(
        [1, 1], [1, 3], [3, 1], [3, 3]
      )
    end

    it 'handles exclusions' do
      config = {
        row_blocks: [2],
        col_blocks: [2],
        exclusions: [{ r: 1, c: 1 }]
      }
      # Resulting seats should be 3 (out of 4)
      expect {
        described_class.generate(section, config)
      }.to change(EventTicketSeat, :count).by(3)
      
      expect(section.event_ticket_seats.where(row_set: 1, col_set: 1)).not_to exist
    end

    context 'with existing seats (Smart Replace)' do
      let(:ticket) { create(:ticket, event: event) }
      
      before do
        # Create some existing seats
        create(:event_ticket_seat, event_seat_section: section, row_set: 1, col_set: 1, name: 'Old-1A')
        create(:event_ticket_seat, event_seat_section: section, row_set: 1, col_set: 2, name: 'Old-1B')
      end

      it 'replaces available seats with new ones' do
        expect {
          described_class.generate(section, { row_blocks: [1], col_blocks: [1] })
        }.to change(EventTicketSeat, :count).by(-1) # 2 old -> 1 new

        expect(section.event_ticket_seats.first.name).to eq("#{section.name}-1A")
      end

      it 'protects sold seats from being deleted' do
        sold_seat = section.event_ticket_seats.find_by(row_set: 1, col_set: 2)
        sold_seat.update!(ticket_id: ticket.id)

        described_class.generate(section, { row_blocks: [1], col_blocks: [1] })

        # Should have the new seat (1,1) AND the sold seat (1,2)
        expect(section.event_ticket_seats.count).to eq(2)
        expect(section.event_ticket_seats.pluck(:row_set, :col_set)).to contain_exactly([1, 1], [1, 2])
        expect(sold_seat.reload.name).to eq('Old-1B')
      end

      it 'avoids creating duplicates on sold seat coordinates' do
        sold_seat = section.event_ticket_seats.find_by(row_set: 1, col_set: 1)
        sold_seat.update!(ticket_id: ticket.id)

        # Generate a grid that includes (1,1)
        described_class.generate(section, { row_blocks: [1], col_blocks: [2] })

        # Result should be: 
        # (1,1) -> the OLD sold seat (preserved)
        # (1,2) -> the NEW generated seat
        expect(section.event_ticket_seats.count).to eq(2)
        expect(section.event_ticket_seats.find_by(row_set: 1, col_set: 1).name).to eq('Old-1A')
        expect(section.event_ticket_seats.find_by(row_set: 1, col_set: 2).name).to eq("#{section.name}-1B")
      end
    end

    it 'generates correct column names for high counts' do
      expect(described_class.send(:col_name, 1)).to eq('A')
      expect(described_class.send(:col_name, 26)).to eq('Z')
      expect(described_class.send(:col_name, 27)).to eq('AA')
      expect(described_class.send(:col_name, 52)).to eq('AZ')
      expect(described_class.send(:col_name, 53)).to eq('BA')
    end
  end
end
