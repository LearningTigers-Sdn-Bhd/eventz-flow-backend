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
end