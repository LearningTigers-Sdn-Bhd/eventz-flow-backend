require 'rails_helper'

RSpec.describe EventSeatSession, type: :model do
  describe 'scopes' do
    let(:event1) { create(:event) }
    let(:event2) { create(:event) }
    
    let!(:session1) { create(:event_seat_session, event: event1, name: 'Session 1') }
    let!(:session2) { create(:event_seat_session, event: event2, name: 'Session 2') }

    describe '.with_deleted' do
      before do
        session1.archive
      end

      it 'includes soft-deleted records' do
        results = described_class.where(event_id: event1.id).with_deleted
        expect(results).to include(session1)
      end

      it 'respects previous scopes (does not return records from other events)' do
        # This was the bug: .with_deleted (via unscoped) was removing the where(event_id: ...) clause
        results = described_class.where(event_id: event1.id).with_deleted
        
        expect(results).to include(session1)
        expect(results).not_to include(session2)
      end
    end

    describe '.only_deleted' do
      before do
        session1.archive
      end

      it 'returns only soft-deleted records' do
        results = described_class.where(event_id: event1.id).only_deleted
        expect(results).to include(session1)
      end

      it 'respects previous scopes' do
        # Archive session2 as well to ensure it's not picked up due to lack of scoping
        session2.archive
        
        results = described_class.where(event_id: event1.id).only_deleted
        
        expect(results).to include(session1)
        expect(results).not_to include(session2)
      end
    end
  end
end
