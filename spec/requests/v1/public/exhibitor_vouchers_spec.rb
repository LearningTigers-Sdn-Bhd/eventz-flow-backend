require 'rails_helper'

RSpec.describe 'Public exhibitor voucher preview', type: :request do
  let(:event) { create(:event, slug: 'test-event', use_exhibitor_kit: true) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 1000) }

  describe 'POST /v1/public/events/:event_slug/exhibitor_vouchers/preview' do
    it 'returns the discounted price for a valid, matching voucher' do
      voucher = create(:exhibitor_voucher, event: event, discount_type: :percentage_off,
        discount_value: 25)

      post "/v1/public/events/#{event.slug}/exhibitor_vouchers/preview",
        params: { voucher_code: voucher.code, exhibitor_booth_price_id: booth_price.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be(true)
      expect(response.parsed_body.dig('data', 'price').to_f).to eq(750)
    end

    it 'uses the selected package price as the discount base' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price,
        price: 1600)
      voucher = create(:exhibitor_voucher, event: event, discount_type: :percentage_off,
        discount_value: 25)

      post "/v1/public/events/#{event.slug}/exhibitor_vouchers/preview",
        params: {
          voucher_code: voucher.code,
          exhibitor_booth_price_id: booth_price.id,
          exhibitor_package_id: package.id
        }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'price').to_f).to eq(1200)
    end

    it 'returns 422 for an invalid code' do
      post "/v1/public/events/#{event.slug}/exhibitor_vouchers/preview",
        params: { voucher_code: 'NOPE1234', exhibitor_booth_price_id: booth_price.id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['message']).to eq('Voucher code is invalid or already used')
    end

    it 'returns 422 when the voucher code is blank' do
      post "/v1/public/events/#{event.slug}/exhibitor_vouchers/preview",
        params: { voucher_code: '  ', exhibitor_booth_price_id: booth_price.id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['message']).to eq('Voucher code is invalid or already used')
    end

    it 'returns 422 when the package does not belong to the selected booth price' do
      other_booth_price = create(:exhibitor_booth_price, event: event,
        exhibitor_zone: booth_price.exhibitor_zone)
      package = create(:exhibitor_package, event: event,
        exhibitor_booth_price: other_booth_price)
      voucher = create(:exhibitor_voucher, event: event)

      post "/v1/public/events/#{event.slug}/exhibitor_vouchers/preview",
        params: {
          voucher_code: voucher.code,
          exhibitor_booth_price_id: booth_price.id,
          exhibitor_package_id: package.id
        }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['message']).to eq(
        'Voucher does not apply to the selected booth price or package'
      )
    end

    it 'does not mark the voucher redeemed' do
      voucher = create(:exhibitor_voucher, event: event)

      post "/v1/public/events/#{event.slug}/exhibitor_vouchers/preview",
        params: { voucher_code: voucher.code, exhibitor_booth_price_id: booth_price.id }

      expect(response).to have_http_status(:ok)
      expect(voucher.reload).to be_active
      expect(voucher.redeemed_at).to be_nil
    end
  end
end
