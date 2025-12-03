require 'rails_helper'

RSpec.describe 'V1::EventRentableItemPrices', type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:rentable_item) { create(:rentable_item) }
  let(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }

  before { sign_in(user) }

  path '/v1/event_rentable_items/{event_rentable_item_id}/event_rentable_item_prices' do
    parameter name: 'event_rentable_item_id', in: :path, type: :string, description: 'event_rentable_item_id'

    get('list event rentable item prices') do
      tags 'Event Rentable Item Prices'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:event_rentable_item_id) { event_rentable_item.id }
        let!(:price_tier1) { create(:event_rentable_item_price_tier, event_rentable_item: event_rentable_item) }
        let!(:price_tier2) { create(:event_rentable_item_price_tier, event_rentable_item: event_rentable_item) }

        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test!
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          run_test!
        end

        context 'as an exhibition contractor for the event' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to be_empty
          end
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { nil }
        let(:event_rentable_item_id) { event_rentable_item.id }
        run_test!
      end
    end

    post('create event rentable item price') do
      tags 'Event Rentable Item Prices'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :event_rentable_item_price_tier, in: :body, schema: {
        type: :object,
        properties: {
          price: { type: :number, format: :float },
          start_date: { type: :string, format: 'date-time' },
          end_date: { type: :string, format: 'date-time' },
          label: { type: :string }
        },
        required: %w[price start_date label]
      }

      let(:event_rentable_item_id) { event_rentable_item.id }
      let(:event_rentable_item_price_tier) do
        {
          event_rentable_item_price_tier: {
            price: 500.00,
            start_date: Time.current.iso8601,
            end_date: (Time.current + 1.month).iso8601,
            label: 'Early Bird'
          }
        }
      end

      response(201, 'created') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test!
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test!
        end
      end
    end
  end

  path '/v1/event_rentable_items/{event_rentable_item_id}/event_rentable_item_prices/{id}' do
    parameter name: 'event_rentable_item_id', in: :path, type: :string, description: 'event_rentable_item_id'
    parameter name: 'id', in: :path, type: :string, description: 'id'

    let(:event_rentable_item_id) { event_rentable_item.id }
    let!(:price_tier_record) { create(:event_rentable_item_price_tier, event_rentable_item: event_rentable_item) }
    let(:id) { price_tier_record.id }

    get('show event rentable item price') do
      tags 'Event Rentable Item Prices'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test!
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          run_test!
        end

        context 'as an exhibition contractor for the event' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test!
        end
      end
    end

    patch('update event rentable item price') do
      tags 'Event Rentable Item Prices'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :event_rentable_item_price_tier, in: :body, schema: {
        type: :object,
        properties: {
          price: { type: :number, format: :float },
          end_date: { type: :string, format: 'date-time' }
        }
      }

      let(:event_rentable_item_price_tier) { { event_rentable_item_price_tier: { price: 600.00, end_date: (Time.current + 2.months).iso8601 } } }

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test!
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test!
        end
      end
    end

    delete('delete event rentable item price') do
      tags 'Event Rentable Item Prices'
      produces 'application/json'
      security [bearerAuth: []]

      response(204, 'no content') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test!
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test!
        end
      end
    end
  end
end
