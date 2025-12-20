require 'rails_helper'

RSpec.describe "V1::Public::Bookings", type: :request do
  let(:event_id) { "24" }
  let(:bm_event_id) { "bm_123" }
  let(:booking_id) { "booking_456" }

  describe "GET /v1/public/bookings/:id" do
    context "when booking ID starts with Pending-" do
      let(:pending_id) { "Pending-abcdef" }
      let(:cached_data) { { id: pending_id, name: "Pending User", status: "pending_confirmation" } }

      it "returns cached data if available" do
        allow(Rails.cache).to receive(:read).with("pending_booking_#{pending_id}").and_return(cached_data)

        get "/v1/public/bookings/#{pending_id}", params: { event_id: event_id, bm_event_id: bm_event_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(pending_id)
        expect(json_response['name']).to eq("Pending User")
      end

      it "returns 404 if data is not in cache" do
        Rails.cache.delete("pending_booking_#{pending_id}")

        get "/v1/public/bookings/#{pending_id}", params: { event_id: event_id, bm_event_id: bm_event_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when booking ID is normal" do
      it "calls BusinessMatchingService" do
        # Mock the service result
        service_result = BaseService::ServiceResult.new(success: true, data: { id: booking_id, name: "Normal User" })
        
        # We need to mock the service instantiation and method call
        service_double = instance_double(BusinessMatchingService)
        allow(BusinessMatchingService).to receive(:new).with(nil).and_return(service_double)
        allow(service_double).to receive(:fetch_single_booking).with(bm_event_id, event_id, booking_id).and_return(service_result)

        get "/v1/public/bookings/#{booking_id}", params: { event_id: event_id, bm_event_id: bm_event_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(booking_id)
        expect(json_response['name']).to eq("Normal User")
      end

      it "returns error if service fails" do
        service_result = BaseService::ServiceResult.new(success: false, errors: "Something went wrong", status: :internal_server_error)
        
        service_double = instance_double(BusinessMatchingService)
        allow(BusinessMatchingService).to receive(:new).with(nil).and_return(service_double)
        allow(service_double).to receive(:fetch_single_booking).with(bm_event_id, event_id, booking_id).and_return(service_result)

        get "/v1/public/bookings/#{booking_id}", params: { event_id: event_id, bm_event_id: bm_event_id }

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
