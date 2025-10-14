require 'rails_helper'



# --- Setup Authorization Headers ---

def auth_headers(token)

	{ 'Authorization' => "Bearer #{token}" }

end



RSpec.describe 'V1::Events', type: :request do

	# --- Setup Users ---

	let(:superadmin_user) { create(:user, role: :superadmin) }

	let(:owner_user) { create(:user, role: :admin) }

	let(:other_user) { create(:user, role: :participant) }



	# --- Setup Tokens ---

	let(:superadmin_token) { JsonWebToken.encode(user_id: superadmin_user.id) }

	let(:owner_token) { JsonWebToken.encode(user_id: owner_user.id) }

	let(:other_token) { JsonWebToken.encode(user_id: other_user.id) }

	# Dummy token

	let(:expired_token) { 'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxfQ.8hPbW2XsP0aR9b4QZGKu7h9L6y9w2QZw' }



	# --- Setup Event Data ---

	let(:event_attributes) { attributes_for(:event, user: owner_user) }

	let(:valid_create_params) do

		{

			event: event_attributes.merge(

				start_date: Time.current + 1.hour,

				end_date: Time.current + 2.hours

			)

		}

	end



	# Create an event owned by the owner_user for testing

	let!(:event_owned) do

		create(:event, user: owner_user, status: :published)

	end





	# Create an event owned by another user for scoping tests

	let!(:event_not_owned) do

		create(:event, user: other_user, status: :published)

	end



	# =========================================================================

	# POST /v1/events (Creation)

  	# =========================================================================



  	describe 'POST /v1/events' do

  		context 'when user is Superadmin (Authorized)' do

  			it 'creates a new event' do

  				expect {

  					post '/v1/events', params: valid_create_params, headers: auth_headers(superadmin_token)

  				}.to change(Event, :count).by(1)

  				expect(response).to have_http_status(:created)

  			end

  		end



  		context 'when user is NOT a Superadmin (Unauthorized by Pundit)' do
			it 'returns 403 Forbidden and does not create' do
			    initial_count = Event.count

			    post '/v1/events', params: valid_create_params, headers: auth_headers(owner_token)

			    expect(response).to have_http_status(:forbidden)
			    expect(Event.count).to eq(initial_count)
			end
		end

  		context 'when token is missing (Unauthorized by JWT)' do

  			it 'returns 401 Unauthorized' do

  				expect {

  					post '/v1/events', params: valid_create_params, headers: {}

  				}.not_to change(Event, :count)

  				expect(response).to have_http_status(:unauthorized)

  			end

  		end

  	end



	# =========================================================================

	# POST /v1/events (Index/Scoping)

  	# =========================================================================



  	describe 'GET /v1/events' do

  		it 'returns only events created by the current user (Owner)' do 

  			get '/v1/events', headers: auth_headers(owner_token)

  			json = JSON.parse(response.body)



			expect(response).to have_http_status(:ok)

			# The owner_user created event_owned, but not event_not_owned

			expect(json.count).to eq(1)

			expect(json.map { |e| e['id'] }).to include(event_owned.id)

  		end



  		it 'returns no events for a user who has created none and is not assigned' do 

  			get '/v1/events', headers: auth_headers(superadmin_token)

  			json = JSON.parse(response.body)



	  		# Superadmin is not the owner or assigned admin/team member of any test event

	  		expect(response).to have_http_status(:ok)

	  		expect(json.count).to eq(0)

  		end

  	end



  	# =========================================================================

 	# GET /v1/events/:id (Show)

	# =========================================================================



  	describe 'GET /v1/events/:id' do

  		context 'when authorized (Owner)' do 

  			it 'returns the event' do

  				get "/v1/events/#{(event_owned.id)}", headers: auth_headers(owner_token)

  				expect(response).to have_http_status(:ok)

  				json = JSON.parse(response.body)

  				expect(json['id']).to eq(event_owned.id)

  			end

  		end



  		context 'when unauthorized (Other User)' do
			it 'returns 403 Forbidden' do
				get "/v1/events/#{event_owned.id}", headers: auth_headers(other_token)

				expect(response).to have_http_status(:forbidden)
			end
		end
  	end



  	# =========================================================================

  	# PUT /v1/events/:id (Update)

  	# =========================================================================



  	describe 'PUT /v1/events/:id' do

  		let(:new_title) { 'Updated Event Title' }

  		let(:update_params) { { event: { title: new_title } } }



  		context 'when authorized (Owner)' do

  			it 'updates the event' do

  				put "/v1/events/#{event_owned.id}", params: update_params, headers: auth_headers(owner_token)

  				event_owned.reload



  				expect(response).to have_http_status(:ok)

  				expect(event_owned.title).to eq(new_title)

  			end

  		end



  		context 'when unauthorized (Other User)' do
			it 'returns 403 Forbidden and does not update' do
				put "/v1/events/#{event_owned.id}", params: update_params, headers: auth_headers(other_token)

				event_owned.reload

				expect(response).to have_http_status(:forbidden)
				expect(event_owned.title).not_to eq(new_title)
			end
		end
  	end



  	# =========================================================================

  	# DELETE /v1/events/:id (Destroy)

  	# =========================================================================

  	describe 'DELETE /v1/events/:id' do
  		context 'when authorized (Owner)' do
  			it 'deletes the event' do
  				expect {
  					delete "/v1/events/#{event_owned.id}", headers: auth_headers(owner_token)
  				}.to change(Event, :count).by(-1)

	  			expect(response).to have_http_status(:no_content)
  			end
  		end

  		context 'when unauthorized (Other User)' do
		    it 'returns 403 Forbidden and does not delete' do
		        initial_count = Event.count
		        
		    	delete "/v1/events/#{event_owned.id}", headers: auth_headers(other_token)

		    	expect(response).to have_http_status(:forbidden)
		    	expect(Event.count).to eq(initial_count)
		    end
		end
  	end
end