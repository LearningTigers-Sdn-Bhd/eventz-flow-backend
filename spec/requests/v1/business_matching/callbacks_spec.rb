# spec/requests/v1/business_matching/callbacks_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::BusinessMatching::Callbacks', type: :request do
  path '/v1/business_matching/receive' do
    post 'Receives data from external workflow' do
      tags 'Business Matching'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          event_id: { type: :integer },
          data: { type: :object }
        },
        required: ['event_id']
      }

      response '200', 'Data received and broadcasted' do
        let(:payload) { { event_id: 123, data: [{ "title" => "Event 1", "slotDuration" => 30 }] } }

        it 'broadcasts to the ActionCable channel' do
          expect(ActionCable.server).to receive(:broadcast).with("business_matching_event_123", hash_including("data" => [{ "title" => "Event 1", "slotDuration" => 30 }]))
          post '/v1/business_matching/receive', params: payload.to_json, headers: { 'Content-Type' => 'application/json' }
        end
        
        run_test!
      end

      response '422', 'Missing event_id' do
        let(:payload) { { some_data: 'test' } }
        run_test!
      end
    end
  end
end
