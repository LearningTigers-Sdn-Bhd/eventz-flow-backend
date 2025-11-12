# visitor_stamps_spec.rb
require 'rails_helper'

RSpec.describe 'V1::VisitorStamps', type: :request do
  # --- Setup Users & Tokens ---
  let(:vendor_user) { create(:user, role: :vendor) }

  # --- Setup Event ---
  let!(:event) do
    create(:event, title: 'Test Event', payment_status: :paid, use_ticket: false)
  end

  # --- Setup Event Vendor ---
  let!(:event_vendor) do
    create(:event_vendor, event: event, vendor: vendor_user, redirect_url: 'https://example.com')
  end

  # --- Setup Visitor ---
  let!(:visitor) do
    create(:visitor, event: event, full_name: 'Test Visitor', email: 'visitor@example.com', phone: '+1234567890')
  end

  describe 'POST /v1/visitors/:public_id/stamps' do
    context 'with valid parameters' do
      it 'creates a stamp for a visitor' do
        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}"

        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['visitor_id']).to eq(visitor.id)
        expect(data['event_vendor_id']).to eq(event_vendor.id)
      end

      it 'returns existing stamp if already stamped' do
        stamp = create(:visitor_vendor_stamp, visitor: visitor, event_vendor: event_vendor)

        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=#{event_vendor.id}"

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['id']).to eq(stamp.id)
      end
    end

    context 'with invalid parameters' do
      it 'returns 404 if visitor not found' do
        post "/v1/visitors/non-existent-id/stamps?event_vendor_id=#{event_vendor.id}"

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 400 if event_vendor_id is missing' do
        post "/v1/visitors/#{visitor.public_id}/stamps"

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns 404 if event_vendor not found' do
        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=99999"

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 400 if visitor belongs to different event' do
        other_event = create(:event, use_ticket: false)
        other_event_vendor = create(:event_vendor, event: other_event, vendor: vendor_user, redirect_url: 'https://example.com')

        post "/v1/visitors/#{visitor.public_id}/stamps?event_vendor_id=#{other_event_vendor.id}"

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
