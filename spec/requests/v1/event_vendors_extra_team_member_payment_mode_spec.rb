# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event vendor extra team member payment mode', type: :request do
  let(:vendor_user) { create(:user, :vendor) }
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let!(:exhibitor) { create(:exhibitor, :with_exhibitor_kit, event: event, vendor: vendor_user) }

  describe 'GET /v1/events/:event_id/vendors' do
    it 'returns payment_gateway mode when the event has a custom gateway' do
      EventPaymentGateway.create!(
        event: event,
        provider: 'razorpay',
        key_id: 'rzp_test_key',
        key_secret: 'secret',
        webhook_secret: 'webhook_secret'
      )

      get "/v1/events/#{event.id}/vendors", headers: auth_headers(vendor_user)

      expect(response).to have_http_status(:ok)
      exhibitor_kit = JSON.parse(response.body).find { |vendor| vendor['id'] == exhibitor.id }['exhibitor_kit']
      expect(exhibitor_kit['extra_team_member_payment_mode']).to eq('payment_gateway')
    end

    it 'returns manual_bank_in mode when the event has no custom gateway' do
      get "/v1/events/#{event.id}/vendors", headers: auth_headers(vendor_user)

      expect(response).to have_http_status(:ok)
      exhibitor_kit = JSON.parse(response.body).find { |vendor| vendor['id'] == exhibitor.id }['exhibitor_kit']
      expect(exhibitor_kit['extra_team_member_payment_mode']).to eq('manual_bank_in')
    end

    it 'returns paid and in-use extra slot counters' do
      create(:exhibitor_team_member_limit, event: event, team_member_limit: 3, extra_team_member_fee: 50.0)
      create_list(:exhibitor_team_member, 3, exhibitor_kit: exhibitor.exhibitor_kit)
      create(
        :exhibitor_team_member_payment,
        :verified,
        exhibitor_kit: exhibitor.exhibitor_kit,
        extra_member_count: 3,
        fee_per_member: 50.0,
        amount: 150.0,
        payee: create(:user)
      )

      get "/v1/events/#{event.id}/vendors", headers: auth_headers(vendor_user)

      expect(response).to have_http_status(:ok)
      exhibitor_kit = JSON.parse(response.body).find { |vendor| vendor['id'] == exhibitor.id }['exhibitor_kit']
      expect(exhibitor_kit['paid_extra_member_count']).to eq(3)
      expect(exhibitor_kit['used_paid_extra_member_count']).to eq(2)
    end
  end
end
