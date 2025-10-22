# analytics_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Analytics', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:staff_user) { create(:staff_user) }
  let(:member_user) { create(:member_user) }

  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:staff_token) { JsonWebToken.encode(user_id: staff_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- Setup Events and Tickets ---
  let!(:event1) { create(:event, status: :published) }
  let!(:event2) { create(:event, status: :published) }
  let!(:ticket_type1) { create(:ticket_type, event: event1, price: 50.00) }
  let!(:ticket_type2) { create(:ticket_type, event: event2, price: 75.00) }

  # Create tickets across multiple events
  let!(:event1_tickets) { create_list(:ticket, 3, event: event1, ticket_type: ticket_type1, status: :purchased) }
  let!(:event1_scanned) { create_list(:ticket, 2, event: event1, ticket_type: ticket_type1, status: :scanned, checked_in: true) }
  let!(:event2_tickets) { create_list(:ticket, 4, event: event2, ticket_type: ticket_type2, status: :purchased) }
  let!(:event2_scanned) { create_list(:ticket, 1, event: event2, ticket_type: ticket_type2, status: :scanned, checked_in: true) }

  # Assign staff user to event1 only
  before do
    EventAssignment.find_or_create_by!(event: event1, user: staff_user, role: :event_admin)
  end

  path '/v1/analytics/total_tickets' do
    get 'Get total tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalTickets: { type: :integer, description: 'Total number of active tickets across all events' }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalTickets']).to eq(10) # 3 + 2 + 4 + 1 = 10 total active tickets
        end
      end

      response '403', 'Forbidden - insufficient permissions' do
        let(:Authorization) { "Bearer #{staff_token}" }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }

        run_test!
      end
    end
  end

  path '/v1/analytics/total_scanned_tickets' do
    get 'Get total scanned tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalScannedTickets: { type: :integer, description: 'Total number of scanned tickets across all events' }
               }

        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedTickets']).to eq(3) # 2 + 1 = 3 scanned tickets
        end
      end
    end
  end

  path '/v1/analytics/total_unscanned_tickets' do
    get 'Get total unscanned tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total unscanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalUnscannedTickets: { type: :integer, description: 'Total number of unscanned tickets across all events' }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalUnscannedTickets']).to eq(7) # 10 total - 3 scanned
        end
      end
    end
  end

  path '/v1/analytics/total_amount_price' do
    get 'Get total sales amount across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 totalAmountPrice: { type: :integer, description: 'Total sales amount in cents across all events' }
               }

        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          # Event1: 5 tickets * 50.00 = 25000 cents
          # Event2: 5 tickets * 75.00 = 37500 cents
          # Total: 62500 cents
          expect(data['totalAmountPrice']).to eq(62500)
        end
      end
    end
  end

  path '/v1/analytics/weekly_registered_tickets' do
    get 'Get weekly registered tickets data across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly registered tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklyRegisteredTickets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
                       count: { type: :integer, description: 'Number of tickets registered on this date' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklyRegisteredTickets']).to be_an(Array)
          expect(data['weeklyRegisteredTickets'].length).to eq(7)
          expect(data['weeklyRegisteredTickets'].first).to have_key('date')
          expect(data['weeklyRegisteredTickets'].first).to have_key('count')
        end
      end
    end
  end

  path '/v1/analytics/weekly_scanned_tickets' do
    get 'Get weekly scanned tickets data across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklyScannedTickets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
                       count: { type: :integer, description: 'Number of tickets scanned on this date' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklyScannedTickets']).to be_an(Array)
          expect(data['weeklyScannedTickets'].length).to eq(7)
        end
      end
    end
  end

  path '/v1/analytics/weekly_sales_amount' do
    get 'Get weekly sales amount data across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklySalesAmount: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
                       count: { type: :integer, description: 'Sales amount in cents for this date' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklySalesAmount']).to be_an(Array)
          expect(data['weeklySalesAmount'].length).to eq(7)
        end
      end
    end
  end
end
