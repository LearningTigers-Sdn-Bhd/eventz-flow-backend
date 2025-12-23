require 'rails_helper'

RSpec.describe BusinessMatchingService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }
  let(:event_id) { 1 }
  let(:bm_event_id) { "bm_123" }

  # Mock Rails.cache for tests involving caching
  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  after do
    Rails.cache.clear
  end

  describe '#fetch_bookings' do
    context 'when data is cached' do
      before do
        allow(Rails.cache).to receive(:read).with("business_matching_bookings_#{event_id}_#{bm_event_id}").and_return({ bookings: [{ id: '1' }] })
      end

      it 'returns cached data' do
        result = service.fetch_bookings(bm_event_id, event_id)
        expect(result.success?).to be true
        expect(result.data[:bookings]).to eq([{ id: '1' }])
      end
    end

    context 'when data is not cached' do
      before do
        Rails.cache.delete("business_matching_bookings_#{event_id}_#{bm_event_id}")
      end

      it 'handles synchronous response with bookings array' do
        response_body = {
          output: [
            {
              "_id" => "booking_1",
              "name" => "Danny",
              "bookingDate" => "03 November"
            }
          ]
        }.to_json

        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .with(
            body: hash_including(action: "Search in Bookings", bm_event_id: bm_event_id),
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: response_body, headers: {})

        result = service.fetch_bookings(bm_event_id, event_id)
        expect(result.success?).to be true
        expect(result.data[:bookings].first[:id]).to eq("booking_1")
        expect(result.data[:bookings].first[:name]).to eq("Danny")
      end

      it 'handles asynchronous response (accepted: true)' do
        response_body = { accepted: true }.to_json

        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .with(
            body: hash_including(action: "Search in Bookings"),
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: response_body, headers: {})

        result = service.fetch_bookings(bm_event_id, event_id)
        expect(result.success?).to be true
        expect(result.data[:bookings]).to eq([])
      end
    end
  end

  describe '#create_booking' do
    let(:booking_params) do
      {
        name: "New User",
        email: "new@example.com",
        phone: "1234567890",
        note: "Test note",
        date: "12 December 2025",
        time: "10:00 AM"
      }
    end

    it 'sends create booking request' do
      stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
        .with(
          body: hash_including(
            action: "Create Booking",
            bm_event_id: bm_event_id,
            name: "New User"
          )
        )
        .to_return(status: 200, body: { success: true }.to_json)

      result = service.create_booking(bm_event_id, event_id, booking_params)
      expect(result.success?).to be true
    end
  end

  describe '#update_booking' do
    let(:booking_id) { "booking_123" }
    let(:update_params) do
      {
        host_comment: "Updated comment",
        potential_deal_value: "5000",
        attendance: "Present"
      }
    end

    it 'sends update booking request' do
      stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
        .with(
          body: hash_including(
            action: "Update Booking",
            bm_event_id: bm_event_id,
            booking_id: booking_id,
            detail2: "Updated comment"
          )
        )
        .to_return(status: 200, body: { success: true }.to_json)

      result = service.update_booking(bm_event_id, event_id, booking_id, update_params)
      expect(result.success?).to be true
    end
  end

  describe '#public_create_booking' do
    let(:host_user_id) { "host_123" }
    let(:booking_params) do
      {
        name: "Public User",
        email: "public@example.com",
        phone: "0987654321",
        date: "15 December 2025",
        time: "2:00 PM"
      }
    end

    context 'when response is accepted (async)' do
      it 'caches the temporary booking and sends confirmation email' do
        # Stub the Fetch Events request which is called internally
        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .with(
            body: hash_including(
              action: "Fetch Events",
              event_id: event_id
            )
          )
          .to_return(status: 200, body: { data: [] }.to_json)

        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .with(
            body: hash_including(
              action: "Public Create Booking",
              bm_event_id: bm_event_id,
              host_user_id: host_user_id
            )
          )
          .to_return(status: 200, body: { accepted: true }.to_json)

        # Mock Mailer
        mailer = double(BookingMailer)
        allow(BookingMailer).to receive(:confirmation_email).and_return(mailer)
        allow(mailer).to receive(:deliver_now)

        result = service.public_create_booking(bm_event_id, event_id, host_user_id, booking_params)

        expect(result.success?).to be true
        expect(result.data['id']).to start_with('Pending-')
        expect(Rails.cache.read("pending_booking_#{result.data['id']}")).to be_present
      end
    end

    context 'when response is synchronous' do
      it 'handles nested booking data and transforms it' do
        # Stub the Fetch Events request which is called internally
        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .with(
            body: hash_including(
              action: "Fetch Events",
              event_id: event_id
            )
          )
          .to_return(status: 200, body: { data: [] }.to_json)

        response_body = {
          output: {
            booking: {
              "_id" => "booking_sync_1",
              "name" => "Public User",
              "bookingDate" => "15 December 2025",
              "cancelBookingLink" => "http://cancel.link"
            }
          }
        }.to_json

        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .to_return(status: 200, body: response_body)

        # Mock Mailer
        mailer = double(BookingMailer)
        allow(BookingMailer).to receive(:confirmation_email).and_return(mailer)
        allow(mailer).to receive(:deliver_later)

        result = service.public_create_booking(bm_event_id, event_id, host_user_id, booking_params)

        expect(result.success?).to be true
        expect(result.data[:id]).to eq("booking_sync_1")
        expect(result.data[:cancel_link]).to eq("http://cancel.link")
      end
    end
  end

  describe '#fetch_single_booking' do
    let(:booking_id) { "booking_456" }

    context 'when initialized with nil user (public context)' do
      let(:public_service) { described_class.new(nil) }

      it 'fetches booking without error' do
        response_body = {
          data: {
            booking: {
              "_id" => booking_id,
              "name" => "Public Guest",
              "bookingDate" => "20 December 2025"
            }
          }
        }.to_json

        stub_request(:post, BusinessMatchingService::WEBHOOK_URL)
          .with(
            body: hash_including(
              action: "Fetch a Booking",
              user_email: nil,
              user_id: nil
            )
          )
          .to_return(status: 200, body: response_body)

        result = public_service.fetch_single_booking(bm_event_id, event_id, booking_id)

        expect(result.success?).to be true
        expect(result.data[:id]).to eq(booking_id)
        expect(result.data[:name]).to eq("Public Guest")
      end
    end

    context 'nested data extraction' do
      it 'extracts from data.booking' do
        response_body = {
          booking: {
            "_id" => booking_id,
            "name" => "Nested 1"
          }
        }.to_json

        stub_request(:post, BusinessMatchingService::WEBHOOK_URL).to_return(status: 200, body: response_body)
        
        result = service.fetch_single_booking(bm_event_id, event_id, booking_id)
        expect(result.data[:name]).to eq("Nested 1")
      end
    end
  end
end