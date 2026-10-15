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

RSpec.describe 'V1::BusinessMatching::Bookings#generate_report', type: :request do
  let(:organizer) { create(:user, role: :organizer) }
  let(:event) { create(:event, user: organizer) }

  def auth_header(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  before do
    allow_any_instance_of(BusinessMatchingService).to receive(:fetch_all_bookings)
      .and_return(BaseService::ServiceResult.new(success: true, data: { bookings: [] }))
  end

  it 'uses a general, event-scoped filename for an admin download' do
    post "/v1/business_matching/events/#{event.id}/report", headers: auth_header(organizer)

    expect(response).to have_http_status(:ok)
    disposition = response.headers['Content-Disposition']
    expect(disposition).to include('business_matching_export')
    expect(disposition).to include(event.title.parameterize(separator: '_'))
  end

  it 'uses a host-specific filename for a business host download' do
    host = create(:user, role: :member, full_name: 'Jamie Host')
    BusinessHostAssignment.create!(event: event, user: host, business_matching_event_id: '1')

    post "/v1/business_matching/events/#{event.id}/report", headers: auth_header(host)

    expect(response).to have_http_status(:ok)
    disposition = response.headers['Content-Disposition']
    expect(disposition).to include('jamie_host')
  end

  it 'generates a unique filename on each download' do
    post "/v1/business_matching/events/#{event.id}/report", headers: auth_header(organizer)
    first_disposition = response.headers['Content-Disposition']

    travel 2.seconds do
      post "/v1/business_matching/events/#{event.id}/report", headers: auth_header(organizer)
    end
    second_disposition = response.headers['Content-Disposition']

    expect(first_disposition).not_to eq(second_disposition)
  end
end
