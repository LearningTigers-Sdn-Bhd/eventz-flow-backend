require 'rails_helper'

RSpec.describe 'V1::Users', type: :request do
  let!(:org_owner) { create(:user, role: :org_owner) }
  let(:member_user) { create(:user, role: :member) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }
  
  let(:auth_header) { { 'Authorization': "Bearer #{member_token}", 'Content-Type': 'application/json' } }

  describe 'POST /v1/users (Registration)' do
    let(:valid_attributes) do
      { user: { email: 'newuser@test.com', password: 'securepassword', password_confirmation: 'securepassword', full_name: 'New Test User' } }
    end

    it 'creates a new user successfully' do
      expect {
        post '/v1/users', params: valid_attributes.to_json, headers: { 'Content-Type': 'application/json' }
      }.to change(User, :count).by(1)
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['user']['email']).to eq('newuser@test.com')
      expect(User.find_by(email: 'newuser@test.com').role).to eq('member')
    end

    it 'returns unprocessable entity with invalid data' do
      invalid_attributes = { user: { email: 'bad_email', password: '123', full_name: 'Bad' } }
      post '/v1/users', params: invalid_attributes.to_json, headers: { 'Content-Type': 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /v1/users/me (Show Profile)' do
    it 'returns the current users profile when authenticated' do
      get '/v1/users/me', headers: auth_header
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['email']).to eq(member_user.email)
    end

    it 'returns 401 Unauthorized when not authenticated' do
      get '/v1/users/me'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /v1/users/me (Update Profile)' do
    let(:update_params) { { user: { full_name: 'Updated Name', phone: '1234567890' } } }

    context 'when authenticated' do
      before do
        put '/v1/users/me', params: update_params.to_json, headers: auth_header
        member_user.reload
      end

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the user data' do
        expect(member_user.full_name).to eq('Updated Name')
      end
    end

    context 'when attempting to change role (Forbidden)' do
      let(:role_change_params) { { user: { role: 'org_owner' } } }
      
      it 'ignores the role change and only updates allowed fields' do
        # UserPolicy update? prevents role change unless org_owner
        put '/v1/users/me', params: role_change_params.to_json, headers: auth_header
        member_user.reload
        expect(member_user.role).to eq('member') # Role remains unchanged
      end
    end
  end
end