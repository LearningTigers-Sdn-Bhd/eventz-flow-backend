require 'swagger_helper'

RSpec.describe 'Exhibitor vouchers API', type: :request do
  let(:event) { create(:event) }
  let(:organizer) { create(:user, role: :organizer) }
  let(:Authorization) { "Bearer #{jwt_token(organizer)}" }

  path '/v1/events/{event_id}/exhibitor_vouchers' do
    parameter name: :event_id, in: :path, type: :integer, required: true

    get('List exhibitor vouchers') do
      tags 'Exhibitor Vouchers'
      produces 'application/json'
      security [{ bearerAuth: [] }]

      response(200, 'successful') do
        let(:event_id) { event.id }

        run_test!
      end
    end

    post('Create exhibitor voucher') do
      tags 'Exhibitor Vouchers'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]
      parameter name: :exhibitor_voucher, in: :body, schema: {
        type: :object,
        properties: {
          exhibitor_voucher: {
            type: :object,
            properties: {
              exhibitor_booth_price_id: { type: :integer, nullable: true },
              exhibitor_package_id: { type: :integer, nullable: true },
              discount_type: {
                type: :string,
                enum: %w[percentage_off fixed_amount_off flat_price]
              },
              discount_value: { type: :number }
            },
            required: %w[discount_type discount_value]
          }
        },
        required: %w[exhibitor_voucher]
      }

      response(201, 'created') do
        let(:event_id) { event.id }
        let(:exhibitor_voucher) do
          {
            exhibitor_voucher: {
              discount_type: 'percentage_off',
              discount_value: 15
            }
          }
        end

        run_test!
      end
    end
  end

  path '/v1/exhibitor_vouchers/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    delete('Delete exhibitor voucher') do
      tags 'Exhibitor Vouchers'
      security [{ bearerAuth: [] }]

      response(204, 'deleted') do
        let(:id) { create(:exhibitor_voucher, event: event).id }

        run_test!
      end

      response(422, 'redeemed voucher cannot be deleted') do
        let(:id) { create(:exhibitor_voucher, :redeemed, event: event).id }

        run_test!
      end
    end
  end

  path '/v1/public/events/{event_slug}/exhibitor_vouchers/preview' do
    parameter name: :event_slug, in: :path, type: :string, required: true

    post('Preview exhibitor voucher') do
      tags 'Exhibitor Vouchers'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :preview_request, in: :body, schema: {
        type: :object,
        properties: {
          voucher_code: { type: :string },
          exhibitor_booth_price_id: { type: :integer },
          exhibitor_package_id: { type: :integer, nullable: true }
        },
        required: %w[voucher_code exhibitor_booth_price_id]
      }

      response(200, 'successful') do
        let(:event_slug) { event.slug }
        let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 1000) }
        let(:voucher) { create(:exhibitor_voucher, event: event) }
        let(:preview_request) do
          {
            voucher_code: voucher.code,
            exhibitor_booth_price_id: booth_price.id
          }
        end

        run_test!
      end

      response(422, 'invalid voucher') do
        let(:event_slug) { event.slug }
        let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 1000) }
        let(:preview_request) do
          {
            voucher_code: 'NOPE1234',
            exhibitor_booth_price_id: booth_price.id
          }
        end

        run_test!
      end
    end
  end
end
