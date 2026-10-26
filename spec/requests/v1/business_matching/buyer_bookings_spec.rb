require 'swagger_helper'

RSpec.describe 'V1::BusinessMatching::Bookings#buyer_bookings', type: :request do
  let(:event) { create(:event, use_business_matching: true) }
  let(:seller) { create(:user, email: 'abby@hotel.example') }
  let(:other_seller) { create(:user, full_name: 'Other Seller') }
  let(:own_session) { make_session('Own Table') }
  let(:other_session) { make_session('Other Table') }

  def make_session(title, for_event: event)
    BusinessMatchingSession.create!(
      event: for_event, title: title, slot_duration: 20, start_time: '09:00', end_time: '17:00',
      start_date: Date.current, end_date: Date.current + 30
    )
  end

  def make_booking(session, host, email:, time:, status: 'Pending')
    BusinessMatchingBooking.create!(
      business_matching_session: session, host_user: host, name: 'Booker', email: email,
      phone: '0123456789', booking_date: Date.current, booking_time: time, duration: 20, status: status
    )
  end

  def auth_header(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  before do
    BusinessHostAssignment.create!(event: event, user: seller, business_matching_event_id: own_session.id.to_s)
    BusinessHostAssignment.create!(event: event, user: other_seller, business_matching_event_id: other_session.id.to_s)
  end

  path '/v1/business_matching/events/{event_id}/buyer_bookings' do
    parameter name: :event_id, in: :path, type: :string, description: 'Internal Event ID'

    get "Retrieves the current user's bookings with other sellers (as a buyer)" do
      tags 'Business Matching'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { event.id }
      let(:Authorization) { auth_header(seller)['Authorization'] }

      response '200', 'Buyer bookings retrieved' do
        before { make_booking(other_session, other_seller, email: seller.email, time: '11:00 AM') }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['bookings'].size).to eq(1)
          expect(data['bookings'].first).to include('event_title' => 'Other Table', 'host_name' => 'Other Seller')
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end

  it 'matches the account email case-insensitively and ignores surrounding spaces' do
    make_booking(other_session, other_seller, email: '  ABBY@Hotel.Example ', time: '11:00 AM')

    get "/v1/business_matching/events/#{event.id}/buyer_bookings", headers: auth_header(seller)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['bookings'].size).to eq(1)
  end

  it "leaves out other people's bookings and bookings in the seller's own session" do
    make_booking(other_session, other_seller, email: 'someone@else.example', time: '11:00 AM')
    make_booking(own_session, seller, email: seller.email, time: '11:20 AM')

    get "/v1/business_matching/events/#{event.id}/buyer_bookings", headers: auth_header(seller)

    expect(JSON.parse(response.body)['bookings']).to be_empty
  end

  it 'leaves out bookings from other events' do
    other_event = create(:event, use_business_matching: true)
    make_booking(make_session('Elsewhere', for_event: other_event), other_seller, email: seller.email, time: '11:00 AM')

    get "/v1/business_matching/events/#{event.id}/buyer_bookings", headers: auth_header(seller)

    expect(JSON.parse(response.body)['bookings']).to be_empty
  end

  it 'orders bookings by time of day, not as text' do
    third_seller = create(:user)
    third_session = make_session('Third Table')
    make_booking(other_session, other_seller, email: seller.email, time: '02:00 PM')
    make_booking(third_session, third_seller, email: seller.email, time: '11:00 AM', status: 'Cancelled')

    get "/v1/business_matching/events/#{event.id}/buyer_bookings", headers: auth_header(seller)

    times = JSON.parse(response.body)['bookings'].map { |b| b['booking_time'] }
    expect(times).to eq(['11:00 AM', '02:00 PM'])
  end

  it 'is forbidden for a user with no business matching access to the event' do
    outsider = create(:user, role: :member)

    get "/v1/business_matching/events/#{event.id}/buyer_bookings", headers: auth_header(outsider)

    expect(response).to have_http_status(:forbidden)
  end

  describe 'staff viewing a seller (?host_user_id=)' do
    let(:organizer) { create(:user, :organizer) }

    before { make_booking(other_session, other_seller, email: seller.email, time: '11:00 AM') }

    it "returns that seller's bookings with other sellers" do
      get "/v1/business_matching/events/#{event.id}/buyer_bookings",
          params: { host_user_id: seller.id }, headers: auth_header(organizer)

      expect(response).to have_http_status(:ok)
      bookings = JSON.parse(response.body)['bookings']
      expect(bookings.map { |b| b['event_title'] }).to eq(['Other Table'])
    end

    it 'is forbidden for a seller looking at another seller' do
      get "/v1/business_matching/events/#{event.id}/buyer_bookings",
          params: { host_user_id: seller.id }, headers: auth_header(other_seller)

      expect(response).to have_http_status(:forbidden)
    end

    it 'lets a seller pass their own id' do
      get "/v1/business_matching/events/#{event.id}/buyer_bookings",
          params: { host_user_id: seller.id }, headers: auth_header(seller)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['bookings'].size).to eq(1)
    end

    it 'returns 404 for a user who is not a seller in this event' do
      get "/v1/business_matching/events/#{event.id}/buyer_bookings",
          params: { host_user_id: create(:user).id }, headers: auth_header(organizer)

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'returns 404 for an unknown event' do
    get '/v1/business_matching/events/0/buyer_bookings', headers: auth_header(seller)

    expect(response).to have_http_status(:not_found)
  end
end
