require 'rails_helper'

RSpec.describe 'V1::ExhibitorPackages', type: :request do
  let(:organizer) { create(:user, role: :organizer) }
  let(:headers) { auth_headers(organizer) }
  let(:event) { create(:event) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event) }

  describe 'GET /v1/events/:event_id/exhibitor_packages' do
    it 'lists packages for the event' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)

      get "/v1/events/#{event.id}/exhibitor_packages", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.first['id']).to eq(package.id)
      expect(json_response.first['booth_price_label']).to eq(booth_price.label)
    end

    it 'rejects an unauthenticated request' do
      get "/v1/events/#{event.id}/exhibitor_packages"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_packages' do
    it 'creates a package' do
      post "/v1/events/#{event.id}/exhibitor_packages", headers: headers, params: {
        exhibitor_package: { exhibitor_booth_price_id: booth_price.id, name: 'Package A | Standard Booth',
                             inclusions: "6D5N hotel\nMeals for 2", price: 7000.0, quota: 40 }
      }

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Package A | Standard Booth')
      expect(json_response['price'].to_f).to eq(7000.0)
    end

    it 'rejects a booth price from another event' do
      foreign_price = create(:exhibitor_booth_price, event: create(:event))

      post "/v1/events/#{event.id}/exhibitor_packages", headers: headers, params: {
        exhibitor_package: { exhibitor_booth_price_id: foreign_price.id, name: 'Package X', price: 1.0 }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /v1/exhibitor_packages/:id' do
    it 'updates the price' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, price: 7000.0)

      patch "/v1/exhibitor_packages/#{package.id}", headers: headers, params: {
        exhibitor_package: { exhibitor_booth_price_id: booth_price.id, name: package.name, price: 7500.0 }
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['price'].to_f).to eq(7500.0)
    end
  end

  describe 'DELETE /v1/exhibitor_packages/:id' do
    it 'deletes an unused package' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)

      delete "/v1/exhibitor_packages/#{package.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(ExhibitorPackage.exists?(package.id)).to be false
    end

    it 'refuses to delete a package with bookings' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)
      create(:exhibitor_kit, exhibitor_package: package)

      delete "/v1/exhibitor_packages/#{package.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(ExhibitorPackage.exists?(package.id)).to be true
    end

    it 'refuses to delete a package used to scope a voucher' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)
      create(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price,
        exhibitor_package: package)

      delete "/v1/exhibitor_packages/#{package.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(ExhibitorPackage.exists?(package.id)).to be(true)
    end
  end
end
