require 'rails_helper'

RSpec.describe 'V1::Sessions', type: :request do
  let!(:member_user) { create(:user, role: :member, email: 'member@example.com', password: 'password123', password_confirmation: 'password123', full_name: 'Regular Member') }
  let(:valid_credentials) { { email: 'member@example.com', password: 'password123' } }
  let(:invalid_credentials) { { email: 'member@example.com', password: 'wrongpassword' } }

  describe 'POST /v1/login' do
    context 'when credentials are valid' do
      before { post '/v1/login', params: valid_credentials.to_json, headers: { 'Content-Type': 'application/json' } }

      it 'returns 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a JWT token and user info' do
        json = JSON.parse(response.body)
        expect(json['token']).to be_present
        expect(json['user']['email']).to eq('member@example.com')
        expect(json['user']['role']).to eq('member')
      end
    end

    context 'when credentials are invalid' do
      before { post '/v1/login', params: invalid_credentials.to_json, headers: { 'Content-Type': 'application/json' } }

      it 'returns 401 Unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns a CustomError message' do
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
        expect(json['message']).to include('Invalid email or password')
      end
    end
  end
end