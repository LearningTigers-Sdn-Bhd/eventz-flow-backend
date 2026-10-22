require 'rails_helper'

RSpec.describe 'V1::SystemNotices', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:headers) { auth_headers(org_owner) }

  describe 'GET /v1/public/system_notice' do
    it 'needs no login and shows nothing while the notice is off' do
      SystemNotice.current.update!(message: 'Update tonight', active: false)

      get '/v1/public/system_notice'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to eq('message' => nil)
    end

    it 'shows the message while the notice is on' do
      SystemNotice.current.update!(message: 'Update tonight 10 PM', active: true)

      get '/v1/public/system_notice'

      expect(JSON.parse(response.body)['data']).to eq('message' => 'Update tonight 10 PM')
    end

    it 'exposes nothing but the message' do
      SystemNotice.current.update!(message: 'Update tonight', active: true)

      get '/v1/public/system_notice'

      expect(JSON.parse(response.body)['data'].keys).to eq(['message'])
    end
  end

  describe 'GET /v1/system_notice' do
    it 'returns the saved notice to org owners, even while off' do
      SystemNotice.current.update!(message: 'Draft text', active: false)

      get '/v1/system_notice', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to eq('message' => 'Draft text', 'active' => false)
    end

    it 'rejects organizers' do
      get '/v1/system_notice', headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires login' do
      get '/v1/system_notice'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /v1/system_notice' do
    it 'lets org owners switch the notice on' do
      patch '/v1/system_notice', params: { message: 'Update tonight 10 PM', active: true }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(SystemNotice.current).to have_attributes(message: 'Update tonight 10 PM', active: true)
    end

    it 'lets org owners switch it off again' do
      SystemNotice.current.update!(message: 'Update tonight', active: true)

      patch '/v1/system_notice', params: { active: false }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(SystemNotice.current.active).to be(false)
    end

    it 'rejects switching on without a message' do
      patch '/v1/system_notice', params: { message: '', active: true }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(SystemNotice.current.active).to be(false)
    end

    it 'rejects organizers' do
      patch '/v1/system_notice', params: { message: 'Hi', active: true }, headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
      expect(SystemNotice.current.active).to be(false)
    end
  end
end
