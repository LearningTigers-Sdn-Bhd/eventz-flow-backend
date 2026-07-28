require 'swagger_helper'

RSpec.describe 'V1::ReceivedPayments', type: :request do
  # Setup users
  let(:org_owner) { create(:user, :org_owner) }
  let(:contractor_user) { create(:user, :exhibition_contractor) }
  let(:vendor_user) { create(:user, :vendor) }

  # Setup event with exhibitor management enabled
  let(:event) { create(:event, use_exhibitor_kit: true, enable_exhibitor_management: true) }
  let(:event_id) { event.id }

  # Create contractor profile and assign to event
  let!(:contractor_profile) do
    contractor_user.reload.exhibition_contractor_profile
  end
  let!(:event_exhibition_contractor) do
    create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile)
  end

  # Setup exhibitor with kit
  let!(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }
  let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }

  # Setup payments where contractor is the payee
  let!(:payment_for_contractor) do
    create(:exhibitor_kit_payment, :submitted_manual_bank_in,
           exhibitor_kit: exhibitor_kit,
           payee: contractor_user,
           amount: 500.00)
  end

  # Setup payment where org_owner is the payee (for printing services)
  let!(:payment_for_org_owner) do
    create(:exhibitor_kit_payment,
           exhibitor_kit: exhibitor_kit,
           payee: org_owner,
           amount: 200.00,
           status: :pending)
  end

  path '/v1/events/{event_id}/received_payments' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'

    get('list received payments for current user') do
      tags 'Received Payments'
      description 'Returns all ExhibitorKitPayments where the current user is the payee. Works for contractors (for their rentable items) and org_owners (for their printing services).'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as a contractor - returns only their payments' do
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to be_an(Array)
            expect(data.length).to eq(1)
            expect(data.first['payee_id']).to eq(contractor_user.id)
            expect(data.first['amount'].to_f).to eq(500.0)
            # Should include exhibitor info
            expect(data.first['exhibitor_info']).to be_present
            expect(data.first['exhibitor_info']['vendor_email']).to eq(vendor_user.email)
          end
        end

        context 'as an org_owner - returns only their payments' do
          let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to be_an(Array)
            expect(data.length).to eq(1)
            expect(data.first['payee_id']).to eq(org_owner.id)
            expect(data.first['amount'].to_f).to eq(200.0)
          end
        end


        context 'with two booths owned by one exhibitor' do
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          let!(:sibling_kit) { create(:exhibitor_kit, event_vendor: exhibitor, booth_number: 'B456') }
          let!(:sibling_payment) do
            create(:exhibitor_kit_payment, exhibitor_kit: sibling_kit, payee: contractor_user)
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.pluck('exhibitor_kit_id')).to contain_exactly(exhibitor_kit.id, sibling_kit.id)
            expect(data.pluck('event_vendor_id').uniq).to eq([exhibitor.id])
            expect(data.pluck('exhibitor_info').pluck('booth_number')).to contain_exactly(
              exhibitor_kit.booth_number,
              sibling_kit.booth_number
            )
          end
        end

        context 'as a vendor (exhibitor) - returns empty if not a payee' do
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to be_an(Array)
            expect(data.length).to eq(0)
          end
        end
      end

      response(401, 'unauthorized') do
        context 'without authentication' do
          let(:Authorization) { nil }
          run_test!
        end
      end

      response(404, 'not found') do
        context 'with invalid event_id' do
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          let(:event_id) { 999999 }
          run_test!
        end
      end
    end
  end
end
