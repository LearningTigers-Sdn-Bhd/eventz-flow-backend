require 'swagger_helper'

RSpec.describe 'V1::ExhibitionContractorProfiles', type: :request do
  path '/v1/exhibition_contractor_profiles/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show exhibition_contractor_profile') do
      tags 'Exhibition Contractor Profiles'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:contractor) { create(:user, :exhibition_contractor, with_profile: true).reload }
        let(:Authorization) { "Bearer #{jwt_token(contractor)}" }
        let(:id) { contractor.exhibition_contractor_profile.id }

        run_test!
      end
    end

    patch('update exhibition_contractor_profile') do
      tags 'Exhibition Contractor Profiles'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :exhibition_contractor_profile, in: :body, schema: {
        type: :object,
        properties: {
          company_name: { type: :string },
          contact_person: { type: :string },
          contact_email: { type: :string },
          contact_phone: { type: :string }
        }
      }

      response(200, 'successful') do
        let(:contractor) { create(:user, :exhibition_contractor, with_profile: true).reload }
        let(:Authorization) { "Bearer #{jwt_token(contractor)}" }
        let(:id) { contractor.exhibition_contractor_profile.id }
        let(:exhibition_contractor_profile) { { company_name: 'Updated Company' } }

        run_test!
      end
    end
  end
end
