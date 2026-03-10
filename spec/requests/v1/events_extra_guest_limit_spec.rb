require 'rails_helper'

RSpec.describe 'V1::Events extra guest limit', type: :request do
  let(:organizer) { create(:user, :organizer) }

  it 'allows creating a wedding event with unlimited guests' do
    post '/v1/events',
         params: {
           event: {
             title: 'Wedding RSVP Event',
             status: 'draft',
             visibility: true,
             use_ticket: false,
             use_wedding: true,
             extra_guest_limit: nil,
             start_date: 1.day.from_now.iso8601,
             end_date: 2.days.from_now.iso8601
           }
         },
         headers: auth_headers(organizer),
         as: :json

    expect(response).to have_http_status(:created)
    expect(json_response['extra_guest_limit']).to be_nil
    expect(Event.find(json_response['id']).extra_guest_limit).to be_nil
  end
end
