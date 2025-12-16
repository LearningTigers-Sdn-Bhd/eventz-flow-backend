require 'rails_helper'

RSpec.describe BusinessMatchingService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }
  let(:event_id) { 1 }
  let(:bm_event_id) { "bm_123" }

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
end