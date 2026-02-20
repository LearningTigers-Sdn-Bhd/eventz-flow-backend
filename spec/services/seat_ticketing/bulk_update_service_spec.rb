require 'rails_helper'

RSpec.describe SeatTicketing::BulkUpdateService do
  let(:event) { create(:event, use_seat_ticketing: true) }
  let(:session) { create(:event_seat_session, event: event) }
  let(:venue) { create(:event_seat_venue, event_seat_session: session) }
  let(:section) { create(:event_seat_section, event_seat_venue: venue, seat_row: 2, seat_column: 2) }

  describe '#call' do
    it 'handles ActionController::Parameters for blueprint_config (Fix 422)' do
      # Set initial state to ensure we detect a "change"
      section.update!(blueprint_config: { row_blocks: [2] })

      params = ActionController::Parameters.new({
        event_seat_venues_attributes: [{
          id: venue.id,
          event_seat_sections_attributes: [{
            id: section.id,
            blueprint_config: { row_blocks: [1], col_blocks: [1], row_gap: 0, col_gap: 0 }
          }]
        }]
      })

      # Mock generate to verify it receives the symbolized hash
      expect(SeatTicketing::SeatGeneratorService).to receive(:generate).with(
        anything, 
        hash_including(row_blocks: [1])
      )

      service = described_class.new(session, params)
      expect(service.call).to be true
    end

    it 'detects blueprint changes and triggers generation' do
      # Set initial config
      section.update!(blueprint_config: { row_blocks: [2], col_blocks: [2] })

      params = ActionController::Parameters.new({
        event_seat_venues_attributes: [{
          id: venue.id,
          event_seat_sections_attributes: [{
            id: section.id,
            blueprint_config: { row_blocks: [5], col_blocks: [5] }
          }]
        }]
      })

      # Should call the generator exactly once for the change
      expect(SeatTicketing::SeatGeneratorService).to receive(:generate).once
      
      described_class.new(session, params).call
    end

    it 'prevents overlapping seats via unique_by (Fix Overlap)' do
      # Create an existing seat at 1,1
      seat = create(:event_ticket_seat, event_seat_section: section, row_set: 1, col_set: 1, name: 'Original')

      # Payload tries to "add" a seat at 1,1 again (common in messy frontend states)
      params = ActionController::Parameters.new({
        event_seat_venues_attributes: [{
          id: venue.id,
          event_seat_sections_attributes: [{
            id: section.id,
            event_ticket_seats_attributes: [
              { name: 'New Clone', row_set: 1, col_set: 1, extra_price: 10 }
            ]
          }]
        }]
      })

      service = described_class.new(session, params)
      expect { service.call }.not_to raise_error
      
      # Should still only have 1 seat at (1,1) but UPDATED
      seats_at_1_1 = section.event_ticket_seats.where(row_set: 1, col_set: 1)
      expect(seats_at_1_1.count).to eq(1)
      expect(seats_at_1_1.first.name).to eq('New Clone')
      expect(seats_at_1_1.first.extra_price).to eq(10)
    end
  end
end
