# spec/services/business_matching_service_spec.rb
require 'rails_helper'

RSpec.describe BusinessMatchingService, type: :service do
  let(:event_id) { 123 }
  let(:bm_event_id) { 456 }
  let(:webhook_url) { BusinessMatchingService::WEBHOOK_URL }

  let(:success_response_body_events) do
    [
      { "id" => 1, "title" => "Event 1", "slotDuration" => 30, "locationLink" => "http://loc1", "adminEmail" => "a1@example.com", "adminWaNumber" => "111" },
      { "id" => 2, "title" => "Event 2", "slotDuration" => 60, "locationLink" => "http://loc2", "adminEmail" => "a2@example.com", "adminWaNumber" => "222" }
    ].to_json
  end

  let(:expected_transformed_events) do
    [
      { id: 1, title: "Event 1", duration: 30, location: "http://loc1", admin_email: "a1@example.com", admin_wa_number: "111" },
      { id: 2, title: "Event 2", duration: 60, location: "http://loc2", admin_email: "a2@example.com", admin_wa_number: "222" }
    ]
  end

  let(:success_response_body_availability) do
    { "dates" => [{ "day" => "Friday", "date" => "12 December 2025", "slots" => 16 }] }.to_json
  end

  let(:error_response_body) { { "error" => "something went wrong" }.to_json }

  describe '#fetch_events' do
    context 'when the webhook call is successful' do
      before do
        stub_request(:post, webhook_url).to_return(status: 200, body: success_response_body_events, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns a successful service result with transformed event data' do
        service = BusinessMatchingService.new(nil)
        result = service.fetch_events(event_id)

        expect(result.success?).to be true
        expect(result.data).to eq(expected_transformed_events)
      end

      it 'sends the correct payload to the webhook' do
        service = BusinessMatchingService.new(nil)
        service.fetch_events(event_id)

        expect(a_request(:post, webhook_url).with(
          body: { action: "Fetch Events", event_id: event_id }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )).to have_been_made.once
      end
    end

    context 'when the webhook call returns an error status' do
      before do
        stub_request(:post, webhook_url).to_return(status: 500, body: error_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an unsuccessful service result with error details' do
        service = BusinessMatchingService.new(nil)
        result = service.fetch_events(event_id)

        expect(result.success?).to be false
        expect(result.status).to eq(500)
        expect(result.errors).to eq(error_response_body)
      end
    end

    context 'when the webhook response is not valid JSON' do
      before do
        stub_request(:post, webhook_url).to_return(status: 200, body: "<html>Not JSON</html>", headers: { 'Content-Type' => 'text/html' })
      end

      it 'returns an unsuccessful service result with a JSON parsing error' do
        service = BusinessMatchingService.new(nil)
        result = service.fetch_events(event_id)

        expect(result.success?).to be false
        expect(result.status).to eq(:bad_gateway)
        expect(result.errors).to include("Failed to parse JSON response")
      end
    end

    context 'when there is a network error' do
      before do
        stub_request(:post, webhook_url).to_raise(Errno::ECONNREFUSED)
      end

      it 'returns an unsuccessful service result with a network error' do
        service = BusinessMatchingService.new(nil)
        result = service.fetch_events(event_id)

        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(result.errors).to include("HTTP request failed")
      end
    end
  end

  describe '#fetch_availability' do
    context 'when the webhook call is successful' do
      before do
        stub_request(:post, webhook_url).to_return(status: 200, body: success_response_body_availability, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns a successful service result with availability data' do
        service = BusinessMatchingService.new(nil)
        result = service.fetch_availability(bm_event_id)

        expect(result.success?).to be true
        expect(result.data).to eq(JSON.parse(success_response_body_availability))
      end

      it 'sends the correct payload to the webhook' do
        service = BusinessMatchingService.new(nil)
        service.fetch_availability(bm_event_id)

        expect(a_request(:post, webhook_url).with(
          body: { action: "Fetch Available Date", bm_event_id: bm_event_id }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )).to have_been_made.once
      end
    end

    context 'when the webhook call returns an error status' do
      before do
        stub_request(:post, webhook_url).to_return(status: 404, body: error_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an unsuccessful service result with error details' do
        service = BusinessMatchingService.new(nil)
        result = service.fetch_availability(bm_event_id)

        expect(result.success?).to be false
        expect(result.status).to eq(404)
        expect(result.errors).to eq(error_response_body)
      end
    end
  end
end
