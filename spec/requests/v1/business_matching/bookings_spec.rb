require 'swagger_helper'

RSpec.describe 'V1::BusinessMatching::Bookings', type: :request do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  let(:event_id) { '1' }
  let(:business_matching_event_id) { 'bm_123' }

  before do
    allow_any_instance_of(BusinessMatchingService).to receive(:fetch_bookings)
      .with(business_matching_event_id, event_id, force_refresh: false)
      .and_return(
        BaseService::ServiceResult.new(success: true, data: { bookings: [] })
      )
  end

  path '/v1/business_matching/events/{business_matching_event_id}/bookings' do
    parameter name: :business_matching_event_id, in: :path, type: :string, description: 'Business Matching Event ID'
    parameter name: :event_id, in: :query, type: :string, required: true, description: 'Internal Event ID'

    get 'Retrieves bookings for a specific business matching event' do
      tags 'Business Matching'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'Bookings retrieved' do
        run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to have_key('bookings')
            expect(data['bookings']).to be_an(Array)
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end
end
