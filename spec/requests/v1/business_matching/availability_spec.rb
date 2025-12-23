# spec/requests/v1/business_matching/availability_spec.rb
require 'swagger_helper'

BUSINESS_MATCHING_AVAILABILITY_SCHEMA = {
  type: :object,
  properties: {
    dates: {
      type: :array,
      items: {
        type: :object,
        properties: {
          day: { type: :string, example: 'Friday' },
          date: { type: :string, example: '12 December 2025' },
          slots: { type: :integer, example: 16 }
        },
        required: ['day', 'date', 'slots']
      }
    }
  },
  required: ['dates']
}.freeze

RSpec.describe 'V1::BusinessMatching::Availability', type: :request do
  let(:organizer_user) { create(:user, :organizer) }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }

  path '/v1/business_matching/events/{business_matching_event_id}/availability' do
    parameter name: :business_matching_event_id, in: :path, type: :string, description: 'ID of the business matching event from the 3rd party system'

    get 'Retrieves availability for a specific business matching event' do
      tags 'Business Matching'
      produces 'application/json'
      # security [{ BearerAuth: [] }] # Public endpoint

      # parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      let(:business_matching_event_id) { 'external_event_id_123' }
      let(:availability_response_data) do
        {
          dates: [
            { day: 'Friday', date: '12 December 2025', slots: 16 },
            { day: 'Saturday', date: '13 December 2025', slots: 8 }
          ]
        }
      end

      before do
        allow_any_instance_of(BusinessMatchingService).to receive(:fetch_availability).and_return(
          BusinessMatchingService::ServiceResult.new(success: true, data: availability_response_data)
        )
      end

      # 1. Success
      response '200', 'Availability data found' do
        # let(:Authorization) { "Bearer #{organizer_token}" }

        schema BUSINESS_MATCHING_AVAILABILITY_SCHEMA
        run_test!
      end

      # 2. Service Error
      response '500', 'Service error' do
        # let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          allow_any_instance_of(BusinessMatchingService).to receive(:fetch_availability).and_return(
            BusinessMatchingService::ServiceResult.new(success: false, errors: 'Webhook connection failed', status: 500)
          )
        end
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['errors']).to eq('Webhook connection failed')
        end
      end
    end
  end
end
