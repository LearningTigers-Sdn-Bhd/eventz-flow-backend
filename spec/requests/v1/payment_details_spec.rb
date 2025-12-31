require 'swagger_helper'

RSpec.describe 'V1::PaymentDetails', type: :request do
  let(:organizer_user) { create(:user, :organizer) }
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:contractor_user) { create(:user, :exhibition_contractor) }
  let(:vendor_user) { create(:user, :vendor) }

  path '/v1/payment_detail/me' do
    get('get current user payment details') do
      tags 'Payment Details'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'when user has payment details' do
          let!(:payment_detail) { create(:payment_detail, user: organizer_user) }
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['bank_name']).to eq(payment_detail.bank_name)
          end
        end
      end

      response(404, 'not found') do
        context 'when user has no payment details' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          run_test!
        end
      end

      response(401, 'unauthorized') do
        context 'without authentication' do
          let(:Authorization) { nil }
          run_test!
        end
      end
    end
  end

  path '/v1/payment_detail' do
    post('create payment details') do
      tags 'Payment Details'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :payment_detail, in: :body, schema: {
        type: :object,
        properties: {
          payment_detail: {
            type: :object,
            required: %w[bank_name account_number account_name],
            properties: {
              bank_name: { type: :string },
              account_number: { type: :string },
              account_name: { type: :string }
            }
          }
        }
      }

      let(:valid_params) do
        {
          payment_detail: {
            bank_name: 'Test Bank',
            account_number: '1234567890',
            account_name: 'John Doe'
          }
        }
      end

      response(201, 'created') do
        context 'as an organizer' do
          let(:fresh_organizer) { create(:user, :organizer) }
          let(:Authorization) { "Bearer #{jwt_token(fresh_organizer)}" }
          let(:payment_detail) { valid_params }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['bank_name']).to eq('Test Bank')
          end
        end

        context 'as an org_owner' do
          let(:fresh_org_owner) { create(:user, :org_owner) }
          let(:Authorization) { "Bearer #{jwt_token(fresh_org_owner)}" }
          let(:payment_detail) { valid_params }
          run_test!
        end

        context 'as an exhibition contractor' do
          let(:fresh_contractor) { create(:user, :exhibition_contractor) }
          let(:Authorization) { "Bearer #{jwt_token(fresh_contractor)}" }
          let(:payment_detail) { valid_params }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as a vendor (not allowed)' do
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
          let(:payment_detail) { valid_params }
          run_test!
        end
      end

      response(422, 'unprocessable entity') do
        context 'with missing required fields' do
          let(:fresh_user_for_validation) { create(:user, :organizer) }
          let(:Authorization) { "Bearer #{jwt_token(fresh_user_for_validation)}" }
          let(:payment_detail) do
            { payment_detail: { bank_name: '' } }
          end
          run_test!
        end
      end
    end

    get('show payment details') do
      tags 'Payment Details'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'when user has payment details' do
          let!(:payment_detail) { create(:payment_detail, user: organizer_user) }
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['bank_name']).to eq(payment_detail.bank_name)
          end
        end
      end

      response(404, 'not found') do
        context 'when user has no payment details' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          run_test!
        end
      end
    end

    patch('update payment details') do
      tags 'Payment Details'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :payment_detail, in: :body, schema: {
        type: :object,
        properties: {
          payment_detail: {
            type: :object,
            properties: {
              bank_name: { type: :string },
              account_number: { type: :string },
              account_name: { type: :string }
            }
          }
        }
      }

      let!(:existing_detail) { create(:payment_detail, user: organizer_user) }

      response(200, 'successful') do
        context 'updating own payment details' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          let(:payment_detail) do
            { payment_detail: { bank_name: 'Updated Bank' } }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['bank_name']).to eq('Updated Bank')
          end
        end
      end

      response(404, 'not found') do
        context 'when user has no payment details' do
          let(:Authorization) { "Bearer #{jwt_token(org_owner_user)}" }
          let(:payment_detail) do
            { payment_detail: { bank_name: 'New Bank' } }
          end
          run_test!
        end
      end
    end

    delete('delete payment details') do
      tags 'Payment Details'
      produces 'application/json'
      security [bearerAuth: []]

      let!(:existing_detail) { create(:payment_detail, user: organizer_user) }

      response(204, 'no content') do
        context 'deleting own payment details' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          run_test!
        end
      end

      response(404, 'not found') do
        context 'when user has no payment details' do
          let(:Authorization) { "Bearer #{jwt_token(org_owner_user)}" }
          run_test!
        end
      end
    end
  end

  describe 'POST /v1/payment_detail' do
    it 'returns 422 when user already has payment details' do
      user = create(:user, :organizer)
      create(:payment_detail, user: user)

      post '/v1/payment_detail',
           params: { payment_detail: { bank_name: 'New', account_number: '999', account_name: 'Test' } },
           headers: { 'Authorization' => "Bearer #{jwt_token(user)}" },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('Payment details already exist')
    end
  end
end
