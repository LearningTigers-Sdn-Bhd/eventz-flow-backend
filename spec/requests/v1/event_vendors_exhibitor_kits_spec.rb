# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/events/:event_id/vendors/exhibitor_kits', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:zone) { create(:exhibitor_zone, event: event, zone: 'Hall A') }
  let(:price) { create(:exhibitor_booth_price, event: event, label: 'Corner', exhibitor_zone: zone) }

  let!(:alpha) { create(:exhibitor, event: event) }
  let!(:beta) { create(:exhibitor, event: event) }
  let!(:alpha_kit) do
    create(:exhibitor_kit, event_vendor: alpha, company_name: 'Alpha Co', booth_number: 'A1',
                           payment_status: :paid, exhibitor_booth_price: price)
  end
  let!(:beta_kit) do
    create(:exhibitor_kit, event_vendor: beta, company_name: 'Beta Co', booth_number: 'B1', payment_status: :unpaid)
  end

  def fetch(**params)
    get "/v1/events/#{event.id}/vendors/exhibitor_kits", params: params, headers: auth_headers(org_owner)
    JSON.parse(response.body)
  end

  it 'returns one row per kit with vendor and pagination headers' do
    rows = fetch(per_page: 1)

    expect(response).to have_http_status(:ok)
    expect(rows.size).to eq(1)
    expect(rows.first['kit']['company_name']).to eq('Alpha Co')
    expect(rows.first['vendor']).not_to have_key('exhibitor_kits')
    expect(rows.first['vendor']['vendor']['full_name']).to be_present
    expect(response.headers['X-Total-Count']).to eq('2')
    expect(response.headers['X-Total-Pages']).to eq('2')
  end

  it 'filters by payment status, pricing label and zone' do
    expect(fetch(payment_status: 'paid').map { |r| r['kit']['id'] }).to eq([alpha_kit.id])
    expect(fetch(booth_pricing: 'Corner').map { |r| r['kit']['id'] }).to eq([alpha_kit.id])
    expect(fetch(zone: 'Hall A').map { |r| r['kit']['id'] }).to eq([alpha_kit.id])
    expect(fetch(zone: '__unassigned__').map { |r| r['kit']['id'] }).to eq([beta_kit.id])
  end

  it 'searches company and booth number' do
    expect(fetch(q: 'beta').map { |r| r['kit']['id'] }).to eq([beta_kit.id])
    expect(fetch(q: 'A1').map { |r| r['kit']['id'] }).to eq([alpha_kit.id])
  end

  it 'sorts by company name' do
    expect(fetch(sort_by: 'company_name', sort_dir: 'desc').map { |r| r['kit']['id'] }).to eq([beta_kit.id, alpha_kit.id])
  end

  it 'rejects signed-in users who are not event staff' do
    outsider = create(:user, :vendor)

    get "/v1/events/#{event.id}/vendors/exhibitor_kits", headers: auth_headers(outsider)

    expect(response).to have_http_status(:forbidden)
  end

  it 'does not fire queries per kit' do
    create_list(:exhibitor_kit, 5, event_vendor: alpha)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].match?(/SAVEPOINT|TRANSACTION/) }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { fetch(per_page: 25) }

    expect(count).to be < 60
  end
end
