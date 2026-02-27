require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorRegistrations', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let!(:zone) { create(:exhibitor_zone, event: event, zone: 'zone_d', quota: 103) }
  let!(:booth_price) do
    create(
      :exhibitor_booth_price,
      event: event,
      exhibitor_zone: zone,
      booth_type: 'shell_scheme',
      label: 'Malaysian',
      price: 1500.00
    )
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_booth_prices' do
    it 'returns published event booth prices' do
      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']).to be_an(Array)
      expect(json['data'].first['label']).to eq('Malaysian')
      expect(json['data'].first['price'].to_f).to eq(1500.0)
      expect(json['data'].first['zone']).to eq('zone_d')
      expect(json['data'].first['zone_quota']).to eq(103)
      expect(json['data'].first['zone_sold_count']).to eq(0)
      expect(json['data'].first['zone_remaining']).to eq(103)
      expect(json['data'].first['zone_available']).to eq(true)
    end
  end

  describe 'POST /v1/public/events/:event_slug/register_exhibitor' do
    let(:email) { "amin-#{SecureRandom.hex(4)}@example.com" }

    let(:params) do
      {
        company_name: 'Acme Energy',
        company_address: 'Kota Kinabalu',
        name_on_fascia: 'ACME ENERGY',
        pic_full_name: 'Amin Rahman',
        pic_position: 'Sales Manager',
        pic_contact_number: '0123456789',
        pic_email_address: email,
        country: 'Malaysia',
        product_category: 'Oil & Gas Equipment',
        payment_option: 'later',
        exhibitor_booth_price_id: booth_price.id,
        custom_fields_data: {
          preferred_booth_location: 'Hall A',
          other_services: ['Advertising Opportunities']
        }
      }
    end

    it 'creates user, exhibitor, kit, and stores profile fields' do
      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      end.to change(User, :count).by(1)
                                 .and change(Exhibitor, :count).by(1)
                                                               .and change(ExhibitorKit, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['price'].to_f).to eq(1500.0)
      expect(json['data']['payment_required']).to be(false)
      expect(json['data']['payment_option']).to eq('later')

      kit = ExhibitorKit.order(created_at: :desc).first
      user = User.find_by!(email: email)
      expect(kit.country).to eq('Malaysia')
      expect(kit.name_on_fascia).to eq('ACME ENERGY')
      expect(kit.pic_position).to eq('Sales Manager')
      expect(kit.exhibitor_booth_price_id).to eq(booth_price.id)
      expect(kit.amount_paid.to_f).to eq(1500.0)
      expect(kit.payment_status).to eq('unpaid')
      expect(kit.custom_fields_data['preferred_booth_location']).to eq('Hall A')
      expect(kit.custom_fields_data['zone']).to eq('zone_d')
      expect(user.authenticate('OgseSabah123')).to eq(user)
      expect(user.vendor_profile.category).to eq('Oil & Gas Equipment')
      expect(user.vendor_profile.person_in_charge).to eq('Amin Rahman')
      expect(user.vendor_profile.address).to eq('Kota Kinabalu')
    end

    it 'returns payment_required true when payment option is now' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params.merge(payment_option: 'now')

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['payment_required']).to be(true)
      expect(json['data']['payment_option']).to eq('now')
    end

    it 'does not overwrite an existing registration for the same email' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      existing_kit = ExhibitorKit.order(created_at: :desc).first

      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params.merge(company_name: 'Overwritten Co')
      end.to change(ExhibitorKit, :count).by(0)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['already_registered']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(existing_kit.id)
      expect(existing_kit.reload.company_name).to eq('Acme Energy')
    end

    it 'returns 422 when the selected zone quota is full' do
      zone.update!(quota: 1)
      create(
        :exhibitor_kit,
        event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price,
        payment_status: :unpaid
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Selected zone is sold out')
    end
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_registration_status' do
    let!(:vendor) do
      create(
        :user,
        :vendor,
        email: 'amin@example.com',
        full_name: 'Amin Rahman'
      )
    end
    let!(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
    let!(:exhibitor_kit) do
      exhibitor.exhibitor_kit.tap do |kit|
        kit.update!(
          exhibitor_booth_price: booth_price,
          pic_email_address: 'amin@example.com',
          payment_status: :paid
        )
      end
    end

    it 'returns existing registration status by email' do
      get "/v1/public/events/#{event.slug}/exhibitor_registration_status", params: { email: 'amin@example.com' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['has_registered']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(exhibitor_kit.id)
      expect(json['data']['payment_status']).to eq('paid')
      expect(json['data']['company_name']).to eq(exhibitor_kit.company_name)
      expect(json['data']['pic_email_address']).to eq('amin@example.com')
      expect(json['data']['zone']).to eq('zone_d')
    end
  end
end
