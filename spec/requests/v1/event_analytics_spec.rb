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
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:staff_user) { create(:user, :staff_member) }
  let(:member_user) { create(:user, :member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event and Tickets ---
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) { create(:ticket_type, event: event, price: 50.00) }

  # Create tickets with different statuses and check-in states
  let!(:purchased_tickets) { create_list(:ticket, 5, event: event, ticket_type: ticket_type, status: :purchased) }
  let!(:scanned_tickets) { create_list(:ticket, 3, event: event, ticket_type: ticket_type, status: :scanned, checked_in: true) }
  let!(:refunded_tickets) { create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :refunded) }

  # Assign users to event
  before do
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event, user: staff_user, role: :event_team_member)
  end

  path '/v1/events/{event_id}/metrics/total_tickets' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

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
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_scanned_tickets' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedTickets']).to eq(3)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_unscanned_tickets' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalUnscannedTickets']).to eq(5) # 8 total - 3 scanned
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_amount_price' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalAmountPrice']).to eq(40000) # 8 tickets * 50.00 * 100 cents
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/weekly_registered' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

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

  path '/v1/events/{event_id}/metrics/weekly_scanned' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklyScannedTickets']).to be_an(Array)
          expect(data['weeklyScannedTickets'].length).to eq(7)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/weekly_sales_amount' do
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
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklySalesAmount']).to be_an(Array)
          expect(data['weeklySalesAmount'].length).to eq(7)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/mall_live_feed' do
    get 'Get live feed dashboard data' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Live feed data retrieved successfully' do
        schema type: :object,
               properties: {
                 shoppers_registered_today: { type: :integer },
                 estimated_sales_today: { type: :string }, # BigDecimal is often serialized as string
                 voucher_issuances: { type: :integer },
                 voucher_redemptions: { type: :integer },
                 redemption_rate: { type: :number },
                 top_merchants: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       name: { type: :string },
                       count: { type: :integer }
                     }
                   }
                 },
                 popular_halls: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       name: { type: :string },
                       percentage: { type: :number }
                     }
                   }
                 }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        
        before do
          # Shoppers (Visitors)
          create_list(:visitor, 3, event: event, created_at: Time.zone.now)
          
          # Vouchers & Redemptions
          voucher = create(:voucher, event: event, total_redemption_available: 100)
          create_list(:voucher_redemption_log, 2, 
            voucher: voucher, 
            transaction_net_amount: 50.0, 
            redemption_timestamp: Time.zone.now,
            redeemer: create(:visitor, event: event),
            redemption_status: 'completed',
            transaction_gross_amount: 50.0,
            discount_applied_value: 0.0
          )
          
          # Top Merchants & Halls
          vendor_user = create(:user, :vendor)
          event_vendor = create(:event_vendor, event: event, vendor: vendor_user)
          
          # Assign Vendor to a Location (Hall A)
          location = create(:event_location, event: event, name: "Hall A")
          create(:event_location_member, event_location: location, member: vendor_user)

          # Create stamps (Traffic)
          4.times do
            create(:visitor_vendor_stamp, event_vendor: event_vendor, visitor: create(:visitor, event: event))
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['shoppers_registered_today']).to eq(8)
          expect(data['estimated_sales_today'].to_f).to eq(100.0) 
          expect(data['voucher_issuances']).to eq(100)
          expect(data['voucher_redemptions']).to eq(2)
          expect(data['redemption_rate']).to eq(2.0)
          expect(data['top_merchants'].length).to eq(1)
          expect(data['top_merchants'][0]['count']).to eq(4)
          
          # Popular Halls Check
          expect(data['popular_halls']).to be_an(Array)
          expect(data['popular_halls'].length).to eq(1)
          expect(data['popular_halls'][0]['name']).to eq("Hall A")
          expect(data['popular_halls'][0]['percentage']).to eq(100.0)
        end
      end
    end
  end
end
