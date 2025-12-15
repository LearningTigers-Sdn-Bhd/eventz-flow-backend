require 'swagger_helper'

RSpec.describe 'V1::ExhibitorKits', type: :request do
  path '/v1/events/{event_id}/exhibitor_kits' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'

    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:event_id) { event.id }

    get('list exhibitor_kits') do
      tags 'Exhibitor Kits'
      produces 'application/json'
      security [bearerAuth: []]

      let(:admin_user) { create(:user, :org_owner) }
      let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
      let!(:contractor_profile) { contractor_user.reload.exhibition_contractor_profile } # Use the one created with the user
      let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
      
      let(:exhibitor_user) { create(:user, :exhibitor) }
      let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) } # Create exhibitor event_vendor
      let!(:exhibitor_kit) { create(:exhibitor_kit, event_vendor: exhibitor) } # Create exhibitor kit

      response(200, 'successful') do
        context 'as an admin' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test!
        end

        context 'as a contractor assigned to the event' do
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test!
        end

        context 'as an exhibitor for the event' do
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end
      end # Closes response(200, 'successful')

      response(403, 'forbidden') do
        context 'as a regular user not assigned to the event' do
          let(:Authorization) { "Bearer #{jwt_token(create(:user))}" }
          run_test!
        end
      end
    end

    post('create exhibitor_kit') do
      tags 'Exhibitor Kits'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :exhibitor_kit, in: :body, schema: {
        type: :object,
        properties: {
          event_vendor_id: { type: :integer },
          booth_number: { type: :string },
          booth_type: { type: :string, enum: ['shell_scheme', 'raw_space'] },
          name_on_fascia: { type: :string },
          company_name: { type: :string },
          company_address: { type: :string },
          pic_full_name: { type: :string },
          pic_contact_number: { type: :string },
          pic_email_address: { type: :string }
        },
        required: %w[event_vendor_id booth_number booth_type name_on_fascia company_name company_address pic_full_name pic_contact_number pic_email_address]
      }

      let(:admin_user) { create(:user, :org_owner) }
      let(:exhibitor_user) { create(:user, :vendor) }
      let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) } # Ensure exhibitor exists
      let(:exhibitor_kit_attributes) do
        {
          event_vendor_id: exhibitor.id,
          booth_number: 'A1',
          booth_type: 'shell_scheme',
          name_on_fascia: 'Test Company',
          company_name: 'Test Company Pte Ltd',
          company_address: '123 Test St',
          pic_full_name: 'John Doe',
          pic_contact_number: '12345678',
          pic_email_address: 'john@example.com'
        }
      end
      let(:exhibitor_kit) { { exhibitor_kit: exhibitor_kit_attributes } }


      response(201, 'created') do
        context 'as an exhibitor creating their own kit' do
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end

        context 'as an admin creating a kit for an exhibitor' do
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'when use_exhibitor_kit is false for the event' do
          let(:event) { create(:event, use_exhibitor_kit: false) }
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end

        context 'as a contractor (cannot create exhibitor kits)' do
          let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
          let!(:contractor_profile) { contractor_user.reload.exhibition_contractor_profile } # Use the one created with the user
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test!
        end
      end
    end
  end

  path '/v1/events/{event_id}/exhibitor_kits/{id}' do
    parameter name: 'event_id', in: :path, type: :string, description: 'ID of the event'
    parameter name: 'id', in: :path, type: :string, description: 'ID of the exhibitor kit'

    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:event_id) { event.id }
    let(:admin_user) { create(:user, :org_owner) }
    let(:exhibitor_user) { create(:user, :exhibitor) }
    let!(:exhibitor) { create(:exhibitor, event: event, vendor: exhibitor_user) }
    let!(:exhibitor_kit_record) { create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid, booth_number: 'A1') }
    let(:id) { exhibitor_kit_record.id }

    patch('update exhibitor_kit') do
      tags 'Exhibitor Kits'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :exhibitor_kit, in: :body, schema: {
        type: :object,
        properties: {
          booth_number: { type: :string },
          payment_status: { type: :string, enum: ['unpaid', 'paid', 'waived', 'sponsored'] },
          company_name: { type: :string }
        }
      }

      response(200, 'successful') do
        context 'as an admin updating any field (e.g., booth_number)' do
          let(:exhibitor_kit) { { exhibitor_kit: { booth_number: 'B2', company_name: 'Admin Changed Co.' } } }
          let(:Authorization) { "Bearer #{jwt_token(admin_user)}" }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['booth_number']).to eq('B2')
            expect(data['company_name']).to eq('Admin Changed Co.')
          end
        end

        context 'as a contractor updating contractor-managed fields (e.g., payment_status)' do
          let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
          let!(:contractor_profile) { contractor_user.reload.exhibition_contractor_profile } # Use the one created with the user
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          let(:exhibitor_kit) { { exhibitor_kit: { payment_status: 'paid' } } }
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['payment_status']).to eq('paid')
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibitor updating their own fields (e.g., company_name)' do
          let(:exhibitor_kit) { { exhibitor_kit: { company_name: 'Updated Exhibitor Co.' } } } # Attempt to update
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test! do |response|
            expect(response).to have_http_status(:forbidden) # Expect 403 Forbidden
          end
        end

        context 'as an exhibitor attempting to update booth_number' do
          let(:exhibitor_kit) { { exhibitor_kit: { booth_number: 'A3' } } }
          let(:Authorization) { "Bearer #{jwt_token(exhibitor_user)}" }
          run_test!
        end

        context 'as a contractor attempting to update an exhibitor-managed field (e.g., company_name)' do
          let(:contractor_user) { create(:user, :exhibition_contractor, with_profile: true) }
          let!(:contractor_profile) { contractor_user.reload.exhibition_contractor_profile } # Use the one created with the user
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          let(:exhibitor_kit) { { exhibitor_kit: { company_name: 'Contractor Changed Co.' } } }
          let(:Authorization) { "Bearer #{jwt_token(contractor_user)}" }
          run_test! do |response|
            expect(response).to have_http_status(:forbidden) # Expect 403 Forbidden
          end
        end
      end
    end
  end
end
