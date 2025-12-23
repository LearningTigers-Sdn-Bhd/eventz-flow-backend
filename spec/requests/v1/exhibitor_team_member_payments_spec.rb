require 'swagger_helper'

RSpec.describe 'V1::ExhibitorTeamMemberPayments', type: :request do
  # Common setup
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:event_id) { event.id }
  let(:admin_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let!(:organizer_assignment) { create(:event_assignment, event: event, user: organizer_user, role: :event_admin) }
  let(:vendor_user) { create(:user, :vendor) }
  let!(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }
  let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }
  let(:exhibitor_kit_id) { exhibitor_kit.id }

  # Setup team member limit (limit 3, fee 50 per extra)
  let!(:team_member_limit) { create(:exhibitor_team_member_limit, event: event, team_member_limit: 3, extra_team_member_fee: 50.00) }

  path '/v1/events/{event_id}/exhibitor_kits/{exhibitor_kit_id}/exhibitor_team_member_payments' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'
    parameter name: 'exhibitor_kit_id', in: :path, type: :string, description: 'ID of the exhibitor kit'

    get('list exhibitor_team_member_payments') do
      tags 'Exhibitor Team Member Payments'
      produces 'application/json'
      security [bearerAuth: []]

      let!(:payment) { create(:exhibitor_team_member_payment, :submitted, exhibitor_kit: exhibitor_kit) }

      response(200, 'successful') do
        context 'as an admin' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to be_an(Array)
          end
        end

        context 'as an organizer assigned to the event' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          run_test!
        end

        context 'as the vendor (exhibitor) for this kit' do
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
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

    post('create exhibitor_team_member_payment') do
      tags 'Exhibitor Team Member Payments'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: 'exhibitor_team_member_payment[payment_proof]', in: :formData, type: :file, required: true
      parameter name: 'exhibitor_team_member_payment[payment_source]', in: :formData, type: :string, enum: ['manual_bank_in', 'payment_gateway']
      parameter name: 'exhibitor_team_member_payment[external_ref]', in: :formData, type: :string, required: false
      parameter name: 'exhibitor_team_member_payment[note]', in: :formData, type: :string, required: false

      # Default values for optional params
      let(:'exhibitor_team_member_payment[external_ref]') { nil }
      let(:'exhibitor_team_member_payment[note]') { nil }

      # Add extra team members beyond limit (exhibitor_kit factory creates 2, limit is 3, so add 2 more = 4 total = 1 excess)
      before do
        create_list(:exhibitor_team_member, 2, exhibitor_kit: exhibitor_kit) # Now 4 total, 1 excess
      end

      response(201, 'created') do
        context 'as the vendor with excess team members' do
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
          let(:'exhibitor_team_member_payment[payment_proof]') { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png') }
          let(:'exhibitor_team_member_payment[payment_source]') { 'manual_bank_in' }
          let(:'exhibitor_team_member_payment[note]') { 'Payment for extra team member' }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['status']).to eq('submitted')
            expect(data['extra_member_count']).to eq(1)
            expect(data['fee_per_member'].to_f).to eq(50.0)
            expect(data['amount'].to_f).to eq(50.0)
          end
        end
      end

      response(422, 'unprocessable entity') do
        context 'when no excess team members' do
          # Reset to only 2 team members (within limit of 3)
          before do
            exhibitor_kit.exhibitor_team_members.destroy_all
            create_list(:exhibitor_team_member, 2, exhibitor_kit: exhibitor_kit)
          end

          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
          let(:'exhibitor_team_member_payment[payment_proof]') { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png') }
          let(:'exhibitor_team_member_payment[payment_source]') { 'manual_bank_in' }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('No unpaid excess team members to pay for')
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an admin (only vendor can create)' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          let(:'exhibitor_team_member_payment[payment_proof]') { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png') }
          let(:'exhibitor_team_member_payment[payment_source]') { 'manual_bank_in' }
          run_test!
        end
      end
    end
  end

  path '/v1/events/{event_id}/exhibitor_kits/{exhibitor_kit_id}/exhibitor_team_member_payments/{id}' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'
    parameter name: 'exhibitor_kit_id', in: :path, type: :string, description: 'ID of the exhibitor kit'
    parameter name: 'id', in: :path, type: :string, description: 'ID of the payment'

    let!(:payment) { create(:exhibitor_team_member_payment, :submitted, exhibitor_kit: exhibitor_kit) }
    let(:id) { payment.id }

    get('show exhibitor_team_member_payment') do
      tags 'Exhibitor Team Member Payments'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['id']).to eq(payment.id)
          end
        end

        context 'as the vendor' do
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as a different vendor' do
          let(:other_vendor) { create(:user, :vendor) }
          let(:Authorization) { "Bearer #{jwt_token(other_vendor)}" }
          run_test!
        end
      end
    end

    patch('update exhibitor_team_member_payment') do
      tags 'Exhibitor Team Member Payments'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :exhibitor_team_member_payment, in: :body, schema: {
        type: :object,
        properties: {
          exhibitor_team_member_payment: {
            type: :object,
            properties: {
              status: { type: :string, enum: ['pending', 'submitted', 'verified', 'rejected'] },
              note: { type: :string },
              paid_at: { type: :string, format: 'date-time' }
            }
          }
        }
      }

      response(200, 'successful') do
        context 'as an organizer verifying payment' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          let(:exhibitor_team_member_payment) do
            {
              exhibitor_team_member_payment: {
                status: 'verified',
                paid_at: Time.current.iso8601
              }
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['status']).to eq('verified')
            expect(data['payee']['id']).to eq(organizer_user.id) # Payee should be recorded
          end
        end

        context 'as an organizer rejecting payment' do
          let(:Authorization) { "Bearer #{jwt_token(organizer_user)}" }
          let(:exhibitor_team_member_payment) do
            {
              exhibitor_team_member_payment: {
                status: 'rejected',
                note: 'Invalid payment proof'
              }
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['status']).to eq('rejected')
          end
        end

        context 'as vendor resubmitting after rejection' do
          let!(:rejected_payment) { create(:exhibitor_team_member_payment, :rejected, exhibitor_kit: exhibitor_kit) }
          let(:id) { rejected_payment.id }
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
          let(:exhibitor_team_member_payment) do
            {
              exhibitor_team_member_payment: {
                payment_source: 'manual_bank_in',
                note: 'Resubmitting with correct proof'
              }
            }
          end

          run_test!
        end

        context 'as vendor trying to verify (status change ignored, update succeeds)' do
          let(:Authorization) { "Bearer #{jwt_token(vendor_user)}" }
          let(:exhibitor_team_member_payment) do
            {
              exhibitor_team_member_payment: {
                status: 'verified',
                note: 'Trying to self-verify'
              }
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            # Status should remain 'submitted' - vendor cannot change status to verified
            expect(data['status']).to eq('submitted')
            # But note should be updated since it's in permitted_attributes
            expect(data['note']).to eq('Trying to self-verify')
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a different vendor' do
          let(:other_vendor) { create(:user, :vendor) }
          let(:Authorization) { "Bearer #{jwt_token(other_vendor)}" }
          let(:exhibitor_team_member_payment) do
            {
              exhibitor_team_member_payment: {
                note: 'Trying to update someone else payment'
              }
            }
          end
          run_test!
        end
      end
    end
  end
end
