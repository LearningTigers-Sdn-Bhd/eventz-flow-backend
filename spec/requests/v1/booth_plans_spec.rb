require 'rails_helper'

RSpec.describe 'V1::BoothPlans', type: :request do
  let(:event) { create(:event) }
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let!(:plan) { create(:booth_plan, event: event, name: 'Kinabatangan I - III', position: 0) }
  let(:image_file) { fixture_file_upload('spec/fixtures/files/test_image.png', 'image/png') }

  describe 'GET /v1/events/:event_id/booth_plans' do
    it 'returns booth plans for org owner' do
      get "/v1/events/#{event.id}/booth_plans", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first['name']).to eq('Kinabatangan I - III')
      expect(json.first).to have_key('image_url')
    end

    it 'forbids a member with no view access to the (draft, unpublished) event' do
      get "/v1/events/#{event.id}/booth_plans", headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      get "/v1/events/#{event.id}/booth_plans"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /v1/events/:event_id/booth_plans' do
    it 'creates a booth plan with an image for org owner' do
      expect do
        post "/v1/events/#{event.id}/booth_plans",
             params: { booth_plan: { name: 'Sipadan I - III', image: image_file } },
             headers: auth_headers(admin_user)
      end.to change(BoothPlan, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Sipadan I - III')
      expect(json['image_url']).to be_present
      expect(json['position']).to eq(1) # after existing plan at position 0
    end

    it 'rejects blank name' do
      post "/v1/events/#{event.id}/booth_plans",
           params: { booth_plan: { name: '' } },
           headers: auth_headers(admin_user)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'forbids member from creating a booth plan' do
      post "/v1/events/#{event.id}/booth_plans",
           params: { booth_plan: { name: 'Sipadan I - III' } },
           headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/events/:event_id/booth_plans/:id' do
    it 'updates name, position and active for org owner' do
      patch "/v1/events/#{event.id}/booth_plans/#{plan.id}",
            params: { booth_plan: { name: 'Renamed Plan', position: 5, active: false } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      plan.reload
      expect(plan.name).to eq('Renamed Plan')
      expect(plan.position).to eq(5)
      expect(plan.active).to eq(false)
    end

    it 'forbids member from updating a booth plan' do
      patch "/v1/events/#{event.id}/booth_plans/#{plan.id}",
            params: { booth_plan: { name: 'Renamed Plan' } },
            headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /v1/events/:event_id/booth_plans/:id' do
    it 'deletes booth plan for org owner' do
      expect do
        delete "/v1/events/#{event.id}/booth_plans/#{plan.id}", headers: auth_headers(admin_user)
      end.to change(BoothPlan, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'forbids member from deleting a booth plan' do
      delete "/v1/events/#{event.id}/booth_plans/#{plan.id}", headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
