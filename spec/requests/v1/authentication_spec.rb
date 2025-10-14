require 'rails_helper'

RSpec.describe 'V1::Authentication', type: :request do
	# Use a transient FactoryBot attribute to create a user for login tests
	let(:password) { 'password123'}
	let!(:user) { create(:user, password: password, password_confirmation: password) }

	describe 'POST /v1/users (User Registration)' do
		let(:valid_params) do
			{
				user: {
					email: 'newuser@example.com',
					password: 'newpassword',
					password_confirmation: 'newpassword',
					full_name: 'John Doe',
					phone: '555-555-5555'
				}
			}
		end

		context 'with valid parameters' do
			it 'creates a new user and returns a token' do
				expect {
					post '/v1/users', params: valid_params
				}.to change(User, :count).by(1)

				expect(response).to have_http_status(:created)
				json = JSON.parse(response.body)

				expect(json['user']).to be_present
				expect(json['token']).to be_present
			end
		end

		context 'with invalid parameters' do
			it 'does not create a user and returns unprocessable_content' do
				# Missing required field: password_confirmation
				invalid_params = valid_params.deep_merge(user: { password_confirmation: 'mismatch' })

				expect {
					post '/v1/users', params: invalid_params
				}.not_to change(User, :count)

				expect(response).to have_http_status(:unprocessable_content)
				json = JSON.parse(response.body)
				expect(json['errors']).to include("Password confirmation doesn't match Password")
			end
		end
	end

	describe 'POST /v1/auth/login (User Login)' do
		let(:valid_login_params) do
			{ email: user.email, password: password }
		end

		let(:invalid_login_params) do
			{ email: user.email, password: 'wrong_password' }
		end

		context 'with valid credentials' do
			it 'returns the user and a JWT token' do
				post '/v1/auth/login', params: valid_login_params

			expect(response).to have_http_status(:ok)
			json = JSON.parse(response.body)

			expect(json['user']['email']).to eq(user.email)
			expect(json['token']).to be_present
			end
		end

		context 'with invalid password' do
			it 'returns an unauthorized error' do 
				post '/v1/auth/login', params: invalid_login_params

				expect(response).to have_http_status(:unauthorized)
				json = JSON.parse(response.body)

				expect(json['error']).to eq('Unauthorized')
				expect(json['message']).to eq('Invalid email or password')
			end
		end

		context 'with non-existent email' do
			it 'returns an unauthorized error' do
				post '/v1/auth/login', params: { email: 'unknown@example.com', password: password }

				expect(response).to have_http_status(:unauthorized)
				json = JSON.parse(response.body)

				expect(json['error']).to eq('Unauthorized')
			end
		end
	end
end