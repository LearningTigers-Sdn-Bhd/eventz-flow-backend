require 'rails_helper'

# The big-screen numbers are public for published events, and only the small
# crowd-against-capacity set.
RSpec.describe 'V1 Public PeopleCounters', type: :request do
  let(:headcount) do
    { configured: true, generated_at: '2026-10-13T10:00:00+08:00',
      event: { inside_now: 200, capacity: 320, in_today: 900, out_today: 700, halls: 3, halls_counted: 2 },
      levels: [
        { floor: 'Level 1', inside_now: 172, capacity: 200, in_today: 900, halls: 1, halls_counted: 1 },
        { floor: 'Level 2', inside_now: 28, capacity: 120, in_today: 10, halls: 2, halls_counted: 1 }
      ],
      halls: [
        { id: 5, name: 'Main Hall', floor: 'Level 1', status: 'ok', inside_now: 172, capacity: 200,
          in_today: 900, out_today: 700, in_event: 3000, out_event: 2800 },
        { id: 6, name: 'Hall B', floor: 'Level 2', status: 'ok', inside_now: 28, capacity: 120 },
        { id: 7, name: 'Hall C', floor: 'Level 2', status: 'unlinked', inside_now: nil, capacity: nil }
      ] }
  end
  let!(:event) { create(:event, status: :published, title: 'Big Expo', use_people_counter: true) }
  let(:url) { "/v1/public/events/#{event.slug}/people_counter" }

  before { allow_any_instance_of(PeopleCounter::EventHeadcount).to receive(:call).and_return(headcount) } # rubocop:disable RSpec/AnyInstance

  it 'shows the crowd for a published event, with no login' do
    get url

    expect(response).to have_http_status(:ok)
    expect(json_response).to include('event_title' => 'Big Expo', 'level' => nil, 'inside_now' => 200, 'capacity' => 320,
                                     'halls_counted' => 2, 'halls_total' => 3)
    expect(json_response['levels'].map { |l| l['floor'] }).to eq(['Level 1', 'Level 2'])
    expect(json_response['halls'].first).to eq('name' => 'Main Hall', 'floor' => 'Level 1', 'status' => 'ok',
                                               'inside_now' => 172, 'capacity' => 200)
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  describe 'one level' do
    it "shows that level's total and only its halls" do
      get url, params: { level: 'Level 2' }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('level' => 'Level 2', 'inside_now' => 28, 'capacity' => 120,
                                       'halls_counted' => 1, 'halls_total' => 2)
      expect(json_response['levels'].map { |l| l['floor'] }).to eq(['Level 2'])
      expect(json_response['halls'].map { |h| h['name'] }).to eq(['Hall B', 'Hall C'])
    end

    it 'is a 404 for a level the event does not have' do
      get url, params: { level: 'Level 9' }
      expect(response).to have_http_status(:not_found)
    end

    it 'matches level text ignoring case and extra spaces, and answers with the real name' do
      ['level 2', ' Level   2 '].each do |level|
        get url, params: { level: level }
        expect(response).to have_http_status(:ok)
        expect(json_response).to include('level' => 'Level 2', 'inside_now' => 28)
      end
    end

    it 'treats a blank level as the whole event' do
      get url, params: { level: '' }
      expect(json_response).to include('level' => nil, 'inside_now' => 200)
    end
  end

  describe 'one hall' do
    it "shows only that hall's figures" do
      get url, params: { hall: 'hall b' }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('hall' => 'Hall B', 'level' => nil, 'inside_now' => 28, 'capacity' => 120,
                                       'halls_counted' => 1, 'halls_total' => 1, 'levels' => [])
      expect(json_response['halls'].map { |h| h['name'] }).to eq(['Hall B'])
    end

    it 'can be narrowed by level too' do
      get url, params: { level: 'Level 1', hall: 'Hall B' }
      expect(response).to have_http_status(:not_found)

      get url, params: { level: 'Level 2', hall: 'Hall B' }
      expect(response).to have_http_status(:ok)
    end

    it 'has no figures for a hall without a working counter' do
      get url, params: { hall: 'Hall C' }

      expect(json_response).to include('hall' => 'Hall C', 'inside_now' => nil, 'halls_counted' => 0)
      expect(json_response['halls'].first['status']).to eq('unlinked')
    end

    it 'is a 404 for a hall the event does not have' do
      get url, params: { hall: 'Hall Z' }
      expect(response).to have_http_status(:not_found)
    end
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

  it 'is a 404 once the People Counter is turned off for the event' do
    event.update!(use_people_counter: false)
    get url
    expect(response).to have_http_status(:not_found)
  end

  it 'is a 404 for an unknown event' do
    get '/v1/public/events/no-such-event/people_counter'
    expect(response).to have_http_status(:not_found)
  end
end
