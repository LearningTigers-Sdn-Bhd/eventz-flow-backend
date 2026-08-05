require 'rails_helper'

RSpec.describe 'V1::ExhibitorVouchers', type: :request do
  let(:event) { create(:event) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:headers) { auth_headers(organizer) }

  describe 'POST /v1/events/:event_id/exhibitor_vouchers' do
    it 'generates a voucher with a server-assigned code' do
      post "/v1/events/#{event.id}/exhibitor_vouchers",
        params: {
          exhibitor_voucher: {
            code: 'CLIENT-CODE',
            discount_type: 'percentage_off',
            discount_value: 15
          }
        },
        headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['code']).to match(/\A[A-Z0-9]{8}\z/)
      expect(response.parsed_body['code']).not_to eq('CLIENT-CODE')
    end
  end

  describe 'GET /v1/events/:event_id/exhibitor_vouchers' do
    it 'lists vouchers for the event with scope labels' do
      booth_price = create(:exhibitor_booth_price, event: event)
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price)
      voucher = create(:exhibitor_voucher, event: event, exhibitor_booth_price: booth_price,
        exhibitor_package: package)
      create(:exhibitor_voucher)

      get "/v1/events/#{event.id}/exhibitor_vouchers", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly(
        a_hash_including(
          'id' => voucher.id,
          'booth_price_label' => booth_price.label,
          'package_name' => package.name
        )
      )
    end
  end

  describe 'DELETE /v1/exhibitor_vouchers/:id' do
    it 'deletes an unredeemed voucher' do
      voucher = create(:exhibitor_voucher, event: event)

      delete "/v1/exhibitor_vouchers/#{voucher.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(ExhibitorVoucher.exists?(voucher.id)).to be(false)
    end

    it 'refuses to delete a redeemed voucher' do
      voucher = create(:exhibitor_voucher, :redeemed, event: event)

      delete "/v1/exhibitor_vouchers/#{voucher.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('A redeemed voucher cannot be deleted')
      expect(ExhibitorVoucher.exists?(voucher.id)).to be(true)
    end

    it 'lets an org owner delete a redeemed voucher' do
      voucher = create(:exhibitor_voucher, :redeemed, event: event)
      org_owner = create(:user, role: :org_owner)

      delete "/v1/exhibitor_vouchers/#{voucher.id}", headers: auth_headers(org_owner)

      expect(response).to have_http_status(:no_content)
      expect(ExhibitorVoucher.exists?(voucher.id)).to be(false)
    end
  end
end
