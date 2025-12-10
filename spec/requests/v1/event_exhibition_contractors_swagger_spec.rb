require 'swagger_helper'

RSpec.describe 'V1::EventExhibitionContractors', type: :request do
  path '/v1/events/{event_id}/event_exhibition_contractor' do
    parameter name: 'event_id', in: :path, type: :string, description: 'event_id'

    get('show event_exhibition_contractor') do
      tags 'Event Exhibition Contractors'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:event) { create(:event) }
        let(:event_id) { event.id }
        let!(:event_contractor) { create(:event_exhibition_contractor, event: event) }

        run_test!
      end
    end

    post('assign event_exhibition_contractor') do
      tags 'Event Exhibition Contractors'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :event_exhibition_contractor, in: :body, schema: {
        type: :object,
        properties: {
          exhibition_contractor_profile_id: { type: :integer }
        },
        required: %w[exhibition_contractor_profile_id]
      }

      response(201, 'created') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:event) { create(:event) }
        let(:event_id) { event.id }
        let(:contractor_profile) { create(:exhibition_contractor_profile) }
        let(:event_exhibition_contractor) { { exhibition_contractor_profile_id: contractor_profile.id } }

        run_test!
      end
    end

    delete('remove event_exhibition_contractor') do
      tags 'Event Exhibition Contractors'
      security [bearerAuth: []]

      response(204, 'successful') do
        let(:org_owner) { create(:user, :org_owner) }
        let(:Authorization) { "Bearer #{jwt_token(org_owner)}" }
        let(:event) { create(:event) }
        let(:event_id) { event.id }
        let!(:event_contractor) { create(:event_exhibition_contractor, event: event) }

        run_test!
      end
    end
  end
end
