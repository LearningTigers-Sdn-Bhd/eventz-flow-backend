require 'rails_helper'

RSpec.describe 'V1::PassBundles', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member)[:access_token] }
  let(:event) do
    event = create(:event, status: :published)
    create(:event_assignment, role: :event_admin, event: event, user: organizer)
    event
  end
  let!(:registration_form) { create(:registration_form, event: event, name: 'Delegate', slug: 'delegate') }
  let!(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate Pass', status: :published, hidden: false) }

  let(:headers) { { 'Authorization' => "Bearer #{organizer_token}" } }

  describe 'GET /v1/events/:event_id/pass_bundles' do
    it 'returns pass bundles with usage summary and bundle link' do
      bundle = create(
        :pass_bundle,
        event: event,
        registration_form: registration_form,
        ticket_type: ticket_type,
        name: 'STB',
        pass_limit: 10,
        payment_mode: :pay_offline,
        payment_status: :unpaid
      )
      create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: bundle)

      get "/v1/events/#{event.id}/pass_bundles", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first).to include(
        'id' => bundle.id,
        'name' => 'STB',
        'pass_limit' => 10,
        'used_count' => 1,
        'remaining_count' => 9,
        'payment_mode' => 'pay_offline',
        'payment_status' => 'unpaid',
        'status' => 'active'
      )
      expect(json.first['bundle_link']).to include("/register/delegate?bundle=#{bundle.token}")
    end
  end

  describe 'POST /v1/events/:event_id/pass_bundles' do
    it 'creates a pass bundle' do
      expect do
        post "/v1/events/#{event.id}/pass_bundles",
             params: {
               pass_bundle: {
                 name: 'Microsoft',
                 pass_limit: 10,
                 registration_form_id: registration_form.id,
                 ticket_type_id: ticket_type.id,
                 payment_mode: 'pay_offline',
                 payment_status: 'sponsored',
                 status: 'active'
               }
             },
             headers: headers
      end.to change(PassBundle, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Microsoft')
      expect(json['payment_status']).to eq('sponsored')
      expect(PassBundle.last.created_by).to eq(organizer)
    end

    it 'rejects users without event update access' do
      post "/v1/events/#{event.id}/pass_bundles",
           params: {
             pass_bundle: {
               name: 'SCC',
               pass_limit: 10,
               registration_form_id: registration_form.id,
               ticket_type_id: ticket_type.id,
               payment_mode: 'free',
               status: 'active'
             }
           },
           headers: { 'Authorization' => "Bearer #{member_token}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/events/:event_id/pass_bundles/:id' do
    it 'updates pass limit upward and status fields' do
      bundle = create(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, pass_limit: 10)

      patch "/v1/events/#{event.id}/pass_bundles/#{bundle.id}",
            params: { pass_bundle: { pass_limit: 15, status: 'paused', payment_status: 'paid' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      bundle.reload
      expect(bundle.pass_limit).to eq(15)
      expect(bundle.status).to eq('paused')
      expect(bundle.payment_status).to eq('paid')
    end

    it 'rejects pass limit below used count' do
      bundle = create(:pass_bundle, event: event, registration_form: registration_form, ticket_type: ticket_type, pass_limit: 2)
      create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: bundle)
      create(:ticket, event: event, ticket_type: ticket_type, pass_bundle: bundle)

      patch "/v1/events/#{event.id}/pass_bundles/#{bundle.id}",
            params: { pass_bundle: { pass_limit: 1 } },
            headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Pass limit cannot be lower than used passes')
    end
  end
end
