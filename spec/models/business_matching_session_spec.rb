require 'rails_helper'

RSpec.describe BusinessMatchingSession do
  let(:event) { create(:event, start_date: 1.day.from_now, end_date: 2.days.from_now) }
  let(:session) do
    described_class.create!(
      event: event,
      title: "VIP Speed Matchmaking",
      slot_duration: 30,
      start_time: "09:00",
      end_time: "11:00"
    )
  end

  def build_booking(status:)
    BusinessMatchingBooking.create!(
      business_matching_session: session,
      name: "Jane Doe",
      email: "jane@example.com",
      phone: "+60123456789",
      booking_date: Date.current,
      booking_time: "09:00",
      duration: 30,
      status: status,
      payment_status: "Free"
    )
  end

  describe '#destroy' do
    it 'succeeds when the session has only cancelled bookings' do
      build_booking(status: 'Cancelled')

      expect(session.destroy).to be_truthy
      expect(described_class.exists?(session.id)).to be false
      expect(BusinessMatchingBooking.where(business_matching_session_id: session.id)).to be_empty
    end

    it 'fails when the session has an active (non-cancelled) booking' do
      build_booking(status: 'Confirmed')

      expect(session.destroy).to be false
      expect(session.errors[:base]).to include(
        "Cannot delete session with active bookings. Please cancel or remove all bookings first."
      )
      expect(described_class.exists?(session.id)).to be true
    end
  end

  describe 'archiving' do
    let(:host_user) { create(:user) }

    describe '#can_be_archived?' do
      it 'is true when there are no bookings and no host attached' do
        expect(session.can_be_archived?).to be true
      end

      it 'is true when there are only cancelled bookings and no host attached' do
        build_booking(status: 'Cancelled')
        expect(session.can_be_archived?).to be true
      end

      it 'is false when a host is attached' do
        BusinessHostAssignment.create!(
          user: host_user,
          event: event,
          business_matching_event_id: session.id.to_s
        )
        expect(session.can_be_archived?).to be false
      end

      it 'is false when active bookings exist' do
        build_booking(status: 'Confirmed')
        expect(session.can_be_archived?).to be false
      end
    end

    describe '#archive!' do
      it 'successfully sets archived_at when eligible' do
        expect(session.archive!).to be_truthy
        expect(session.archived?).to be true
        expect(session.archived_at).to be_present
      end

      it 'fails and adds an error when a host is attached' do
        BusinessHostAssignment.create!(
          user: host_user,
          event: event,
          business_matching_event_id: session.id.to_s
        )

        expect(session.archive!).to be false
        expect(session.errors[:base]).to include('Cannot archive session with an assigned host. Please detach the host first.')
        expect(session.archived?).to be false
      end

      it 'fails and adds an error when active bookings exist' do
        build_booking(status: 'Confirmed')

        expect(session.archive!).to be false
        expect(session.errors[:base]).to include('Cannot archive session with active bookings. Please cancel or remove all bookings first.')
        expect(session.archived?).to be false
      end
    end

    describe '#unarchive!' do
      it 'clears archived_at' do
        session.archive!
        expect(session.archived?).to be true

        session.unarchive!
        expect(session.archived?).to be false
        expect(session.archived_at).to be_nil
      end
    end

    describe 'scopes' do
      let!(:archived_session) do
        described_class.create!(
          event: event,
          title: "Archived Session",
          slot_duration: 30,
          start_time: "09:00",
          end_time: "11:00",
          archived_at: Time.current
        )
      end

      it '.unarchived returns only non-archived sessions' do
        expect(described_class.unarchived).to include(session)
        expect(described_class.unarchived).not_to include(archived_session)
      end

      it '.archived returns only archived sessions' do
        expect(described_class.archived).to include(archived_session)
        expect(described_class.archived).not_to include(session)
      end
    end
  end
end

