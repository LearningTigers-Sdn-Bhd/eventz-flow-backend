# visitor_stamps_spec.rb
require 'rails_helper'

RSpec.describe 'V1::VisitorStamps', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner) { create(:user, role: :org_owner) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:vendor_user) { create(:user, role: :vendor) }
  let(:other_vendor) { create(:user, role: :vendor) }
  
  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }
  let(:other_vendor_token) { JwtService.generate_tokens(other_vendor)[:access_token] }

  # --- Setup Event ---
  let!(:event) do
    create(:event, title: 'Test Event', payment_status: :paid, use_ticket: false)
  end

  # --- Setup Event Vendors ---
  let!(:event_vendor) do
    create(:event_vendor, event: event, vendor: vendor_user, redirect_url: 'https://example.com')
  end

  let!(:other_event_vendor) do
    create(:event_vendor, event: event, vendor: other_vendor, redirect_url: 'https://example.com')
  end

  # --- Setup Visitors ---
  let!(:visitor) do
    create(:visitor, event: event, full_name: 'Test Visitor', email: 'visitor@example.com', phone: '+1234567890')
  end

  let!(:visitor2) do
    create(:visitor, event: event, full_name: 'Second Visitor', email: 'visitor2@example.com', phone: '+0987654321')
  end

  # --- Setup Stamps ---
  let!(:vendor_stamp) do
    create(:visitor_vendor_stamp, visitor: visitor, event_vendor: event_vendor)
  end

  let!(:other_vendor_stamp) do
    create(:visitor_vendor_stamp, visitor: visitor2, event_vendor: other_event_vendor)
  end

  describe 'GET /v1/events/:event_id/visitor-stamps' do
    context 'when user is org_owner' do
      it 'returns all stamps for the event' do
        get "/v1/events/#{event.id}/visitor-stamps", headers: { 'Authorization' => "Bearer #{org_owner_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data.length).to eq(2)
      end
    end

    context 'when user is organizer' do
      it 'returns all stamps for the event' do
        get "/v1/events/#{event.id}/visitor-stamps", headers: { 'Authorization' => "Bearer #{organizer_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data.length).to eq(2)
      end
    end

    context 'when user is a vendor' do
      it 'returns only their own stamps' do
        get "/v1/events/#{event.id}/visitor-stamps", headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data.length).to eq(1)
        expect(data[0]['vendor_name']).to eq(vendor_user.full_name)
      end

      it 'does not return other vendors stamps' do
        get "/v1/events/#{event.id}/visitor-stamps", headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        vendor_names = data.map { |stamp| stamp['vendor_name'] }
        expect(vendor_names).not_to include(other_vendor.full_name)
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get "/v1/events/#{event.id}/visitor-stamps"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when event does not exist' do
      it 'returns 404 not found' do
        get "/v1/events/99999/visitor-stamps", headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /v1/visitors/:public_id/stamps' do
    context 'when vendor creates stamp for themselves' do
      it 'creates a stamp successfully' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')
        
        post "/v1/visitors/#{new_visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['visitor_id']).to eq(new_visitor.id)
        expect(data['event_vendor_id']).to eq(event_vendor.id)
      end

      it 'returns existing stamp if already stamped' do
        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['id']).to eq(vendor_stamp.id)
      end
    end

    context 'when vendor tries to create stamp for another vendor' do
      it 'returns 403 forbidden' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')
        
        post "/v1/visitors/#{new_visitor.public_id}/stamps?event_vendor_id=#{other_event_vendor.id}",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when org_owner creates stamp' do
      it 'can create stamp for any vendor' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')
        
        post "/v1/visitors/#{new_visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}",
             headers: { 'Authorization' => "Bearer #{org_owner_token}" }

        expect(response).to have_http_status(:created)
      end
    end

    context 'when organizer creates stamp' do
      it 'can create stamp for any vendor' do
        new_visitor = create(:visitor, event: event, full_name: 'New Visitor')
        
        post "/v1/visitors/#{new_visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}",
             headers: { 'Authorization' => "Bearer #{organizer_token}" }

        expect(response).to have_http_status(:created)
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid parameters' do
      it 'returns 404 if visitor not found' do
        post "/v1/visitors/non-existent-id/stamps?event_vendor_id=#{event_vendor.id}",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 400 if event_vendor_id is missing' do
        post "/v1/visitors/#{visitor.public_id}/stamps",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns 404 if event_vendor not found' do
        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=99999",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 400 if visitor belongs to different event' do
        other_event = create(:event, use_ticket: false)
        other_event_vendor_diff = create(:event_vendor, event: other_event, vendor: vendor_user, redirect_url: 'https://example.com')

        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=#{other_event_vendor_diff.id}",
             headers: { 'Authorization' => "Bearer #{vendor_token}" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
