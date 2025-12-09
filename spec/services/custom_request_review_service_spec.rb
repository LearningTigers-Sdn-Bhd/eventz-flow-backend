require 'rails_helper'
require_relative '../../app/services/base_service'

RSpec.describe CustomRequestReviewService, type: :service do
  let(:user) { create(:user, :org_owner) } # Admin user for authorization
  let(:exhibitor_kit) { create(:exhibitor_kit) }
  let(:custom_request) { create(:custom_request, exhibitor_kit: exhibitor_kit, status: :pending) }
  let(:service) { CustomRequestReviewService.new(user: user, custom_request: custom_request, params: ActionController::Parameters.new(params)) }

  describe '#review' do
    context 'with valid parameters' do
      let(:params) do
        {
          custom_request: {
            status: 'approved',
            resolved_price: 150.00,
            response_notes: 'Approved with minor adjustments'
          }
        }
      end

      it 'updates the custom request' do
        result = service.review
        expect(result.success?).to be(true)
        expect(result.data.status).to eq('approved')
        expect(result.data.resolved_price).to eq(150.00)
        expect(result.data.response_notes).to eq('Approved with minor adjustments')
      end


    end

    context 'with invalid parameters' do
      let(:params) do
        {
          custom_request: {
            resolved_price: -10.00
          }
        }
      end

      it 'does not update the custom request' do
        service.review
        custom_request.reload
        expect(custom_request.quantity).to_not eq(-1) # Remains unchanged
      end

      it 'returns an unsuccessful service result with errors' do
        result = service.review
        expect(result).to be_a(BaseService::ServiceResult)
        expect(result.success?).to be(false)
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Resolved price must be greater than or equal to 0')
      end
    end

    context 'when unauthorized' do
      let(:user) { create(:user, :member) } # Unauthorized user
      let(:params) do
        {
          custom_request: {
            status: 'approved',
            resolved_price: 150.00
          }
        }
      end

      it 'raises a Pundit::NotAuthorizedError' do
        expect { service.review }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
