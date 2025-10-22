# event_analytics_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS FOR EVENT ANALYTICS
# =========================================================================

EVENT_ANALYTICS_SCHEMA = {
  type: :object,
  properties: {
    totalTickets: { type: :integer, description: 'Total number of active tickets for the event' },
    totalScannedTickets: { type: :integer, description: 'Number of tickets that have been scanned' },
    totalUnscannedTickets: { type: :integer, description: 'Number of tickets that have not been scanned' },
    totalAmountPrice: { type: :integer, description: 'Total sales amount in cents' },
    weeklyRegisteredTickets: {
      type: :array,
      items: {
        type: :object,
        properties: {
          date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
          count: { type: :integer, description: 'Number of tickets registered on this date' }
        }
      }
    },
    weeklyScannedTickets: {
      type: :array,
      items: {
        type: :object,
        properties: {
          date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
          count: { type: :integer, description: 'Number of tickets scanned on this date' }
        }
      }
    },
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
}.freeze

RSpec.describe 'V1::EventAnalytics', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:staff_user) { create(:staff_user) }
  let(:member_user) { create(:member_user) }

  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:staff_token) { JsonWebToken.encode(user_id: staff_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- Setup Event and Tickets ---
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) { create(:ticket_type, event: event, price: 50.00) }

  # Create tickets with different statuses and check-in states
  let!(:purchased_tickets) { create_list(:ticket, 5, event: event, ticket_type: ticket_type, status: :purchased) }
  let!(:scanned_tickets) { create_list(:ticket, 3, event: event, ticket_type: ticket_type, status: :scanned, checked_in: true) }
  let!(:refunded_tickets) { create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :refunded) }

  # Assign users to event
  before do
    EventAssignment.find_or_create_by!(event: event, user: manager_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event, user: staff_user, role: :event_team_member)
  end

  path '/v1/events/{event_id}/analytics/total_tickets' do
    get 'Get total tickets count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalTickets']).to eq(8) # 5 purchased + 3 scanned (excludes refunded)
        end
      end

      response '403', 'Forbidden - insufficient permissions' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{member_token}" }

        run_test!
      end

      response '404', 'Event not found' do
        let(:event_id) { 99999 }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/analytics/total_scanned_tickets' do
    get 'Get total scanned tickets count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalScannedTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedTickets']).to eq(3)
        end
      end
    end
  end

  path '/v1/events/{event_id}/analytics/total_unscanned_tickets' do
    get 'Get total unscanned tickets count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total unscanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalUnscannedTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalUnscannedTickets']).to eq(5) # 8 total - 3 scanned
        end
      end
    end
  end

  path '/v1/events/{event_id}/analytics/total_amount_price' do
    get 'Get total sales amount for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 totalAmountPrice: { type: :integer, description: 'Amount in cents' }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalAmountPrice']).to eq(40000) # 8 tickets * 50.00 * 100 cents
        end
      end
    end
  end

  path '/v1/events/{event_id}/analytics/weekly_registered_tickets' do
    get 'Get weekly registered tickets data for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly registered tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklyRegisteredTickets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date },
                       count: { type: :integer }
                     }
                   }
                 }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

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

  path '/v1/events/{event_id}/analytics/weekly_scanned_tickets' do
    get 'Get weekly scanned tickets data for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklyScannedTickets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date },
                       count: { type: :integer }
                     }
                   }
                 }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklyScannedTickets']).to be_an(Array)
          expect(data['weeklyScannedTickets'].length).to eq(7)
        end
      end
    end
  end

  path '/v1/events/{event_id}/analytics/weekly_sales_amount' do
    get 'Get weekly sales amount data for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklySalesAmount: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date },
                       count: { type: :integer, description: 'Amount in cents' }
                     }
                   }
                 }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklySalesAmount']).to be_an(Array)
          expect(data['weeklySalesAmount'].length).to eq(7)
        end
      end
    end
  end
end
