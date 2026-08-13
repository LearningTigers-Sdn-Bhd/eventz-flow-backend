require 'rails_helper'

RSpec.describe BusinessMatchingService do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }
  let(:event) { create(:event, start_date: 1.day.from_now, end_date: 2.days.from_now) }
  let!(:session) do
    BusinessMatchingSession.create!(
      event: event,
      title: "VIP Speed Matchmaking",
      slot_duration: 30,
      location: "VIP Lounge",
      admin_email: "admin@event.com",
      admin_wa_number: "+60123456789",
      start_time: "09:00",
      end_time: "11:00"
    )
  end

  describe '#fetch_events' do
    it 'returns all active sessions' do
      result = service.fetch_events(event.id)
      expect(result.success?).to be true
      expect(result.data.size).to eq(1)
      expect(result.data.first[:title]).to eq("VIP Speed Matchmaking")
      expect(result.data.first[:duration]).to eq(30)
      expect(result.data.first[:location]).to eq("VIP Lounge")
    end
  end

  describe '#fetch_availability' do
    context 'with default session hours (no custom availabilities in DB)' do
      it 'generates default slots count based on event days' do
        result = service.fetch_availability(session.id, event.id)
        expect(result.success?).to be true
        expect(result.data[:dates].size).to eq(2) # 2 days event

        first_day = result.data[:dates].first
        expect(first_day[:slots]).to eq(4) # 09:00, 09:30, 10:00, 10:30 (11:00 is end time)
      end
    end

    context 'with custom availabilities in DB' do
      before do
        # Create availability only for the first event day: 09:00 to 10:00 (2 slots)
        BusinessMatchingAvailability.create!(
          business_matching_session: session,
          day: event.start_date.to_date,
          start_time: "09:00",
          end_time: "10:00"
        )
      end

      it 'respects custom availability and ignores fallback event days' do
        result = service.fetch_availability(session.id, event.id)
        expect(result.success?).to be true
        expect(result.data[:dates].size).to eq(1)

        first_day = result.data[:dates].first
        expect(first_day[:slots]).to eq(2) # 09:00, 09:30
      end
    end
  end

  describe '#fetch_detailed_slots' do
    let(:date_str) { event.start_date.to_date.strftime("%d %B %Y") }

    it 'returns all slot times' do
      result = service.fetch_detailed_slots(session.id, date_str, event.id)
      expect(result.success?).to be true
      expect(result.data[:slots].map { |s| s[:slot] }).to eq(["09:00 AM", "09:30 AM", "10:00 AM", "10:30 AM"])
    end

    context 'when slots are booked' do
      before do
        # Assign user as host
        BusinessHostAssignment.create!(
          user: user,
          event: event,
          business_matching_event_id: session.id.to_s
        )

        BusinessMatchingBooking.create!(
          business_matching_session: session,
          host_user: user,
          name: "John Visitor",
          email: "john@visitor.com",
          phone: "0123",
          booking_date: event.start_date.to_date,
          booking_time: "09:30 AM",
          duration: 30,
          status: "Confirmed",
          payment_status: "Pending"
        )
      end

      it 'excludes booked slots' do
        result = service.fetch_detailed_slots(session.id, date_str, event.id)
        expect(result.success?).to be true
        expect(result.data[:slots].map { |s| s[:slot] }).to eq(["09:00 AM", "10:00 AM", "10:30 AM"])
      end
    end
  end

  describe '#create_booking' do
    let(:host) { create(:user) }
    before do
      BusinessHostAssignment.create!(
        user: host,
        event: event,
        business_matching_event_id: session.id.to_s
      )
    end

    it 'creates a booking successfully' do
      params = {
        name: "Alice Visitor",
        email: "alice@example.com",
        phone: "+6012",
        date: event.start_date.to_date.to_s,
        time: "10:00 AM"
      }

      result = service.create_booking(session.id, event.id, params)
      expect(result.success?).to be true
      expect(result.data[:name]).to eq("Alice Visitor")
      expect(result.data[:host_user_id]).to eq(host.id.to_s)
    end

    it 'emails both the participant and the host a confirmation' do
      params = {
        name: "Alice Visitor",
        email: "alice@example.com",
        phone: "+6012",
        date: event.start_date.to_date.to_s,
        time: "10:00 AM"
      }

      perform_enqueued_jobs do
        expect { service.create_booking(session.id, event.id, params) }
          .to change { ActionMailer::Base.deliveries.size }.by(2)
      end

      recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
      expect(recipients).to contain_exactly("alice@example.com", host.email)
    end

    it 'prevents double booking for the same host' do
      params = {
        name: "Alice Visitor",
        email: "alice@example.com",
        phone: "+6012",
        date: event.start_date.to_date.to_s,
        time: "10:00 AM"
      }

      # First booking
      service.create_booking(session.id, event.id, params)

      # Second booking on the same slot
      result2 = service.create_booking(session.id, event.id, params)
      expect(result2.success?).to be false
      expect(result2.errors).to include("already booked")
    end
  end

  describe '#public_create_booking' do
    let(:host) { create(:user) }
    before do
      BusinessHostAssignment.create!(
        user: host,
        event: event,
        business_matching_event_id: session.id.to_s
      )
    end

    it 'stores the booker profile fields separately from the internal host comment' do
      params = {
        name: "Alice Visitor",
        email: "alice@example.com",
        phone: "+6012",
        date: event.start_date.to_date.to_s,
        time: "10:00 AM",
        booker_description: "We build fintech infrastructure",
        booker_sourcing_intent: "Looking for banking partners",
        booker_capabilities: "Core ledger APIs"
      }

      result = service.public_create_booking(session.id, event.id, nil, params)
      expect(result.success?).to be true
      expect(result.data[:booker_description]).to eq("We build fintech infrastructure")
      expect(result.data[:booker_sourcing_intent]).to eq("Looking for banking partners")
      expect(result.data[:booker_capabilities]).to eq("Core ledger APIs")
      expect(result.data[:host_comment]).to eq("")
    end
  end
end