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
end
