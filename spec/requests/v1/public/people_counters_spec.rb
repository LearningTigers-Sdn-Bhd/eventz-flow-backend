require 'rails_helper'

# The big-screen numbers are public for published events, and only the small
# crowd-against-capacity set.
RSpec.describe 'V1 Public PeopleCounters', type: :request do
  let(:headcount) do
    { configured: true, generated_at: '2026-10-13T10:00:00+08:00',
      event: { inside_now: 172, capacity: 200, in_today: 900, out_today: 700 },
      levels: [{ floor: 'Level 1', inside_now: 172, capacity: 200, in_today: 900 }],
      halls: [{ id: 5, name: 'Main Hall', floor: 'Level 1', status: 'ok', inside_now: 172, capacity: 200,
                in_today: 900, out_today: 700, in_event: 3000, out_event: 2800 }] }
  end
  let!(:event) { create(:event, status: :published, title: 'Big Expo') }
  let(:url) { "/v1/public/events/#{event.slug}/people_counter" }

  before { allow_any_instance_of(PeopleCounter::EventHeadcount).to receive(:call).and_return(headcount) } # rubocop:disable RSpec/AnyInstance

  it 'shows the crowd for a published event, with no login' do
    get url

    expect(response).to have_http_status(:ok)
    expect(json_response).to include('event_title' => 'Big Expo', 'inside_now' => 172, 'capacity' => 200)
    expect(json_response['halls']).to eq([{ 'name' => 'Main Hall', 'floor' => 'Level 1', 'status' => 'ok',
                                            'inside_now' => 172, 'capacity' => 200 }])
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'leaves out traffic totals and ids' do
    get url
    expect(response.body).not_to match(/in_today|out_today|in_event|out_event|"id"/)
  end

  it 'is a 404 for an unpublished event' do
    event.update!(status: :draft)
    get url
    expect(response).to have_http_status(:not_found)
  end

  it 'is a 404 for an unknown event' do
    get '/v1/public/events/no-such-event/people_counter'
    expect(response).to have_http_status(:not_found)
  end
end
