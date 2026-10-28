# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Exhibitor kit tags', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_exhibitor_kit: true, exhibitor_tags_per_kit: 2) }
  let(:headers) { auth_headers(org_owner) }
  let(:base) { "/v1/events/#{event.id}/exhibitor_kits" }

  let!(:jetsin_vendor) { create(:exhibitor, event: event) }
  let!(:other_vendor) { create(:exhibitor, event: event) }
  let!(:k1) { create(:exhibitor_kit, event_vendor: jetsin_vendor, company_name: 'Jetsin Berhad', booth_number: 'K1', payment_status: :paid) }
  let!(:k2) { create(:exhibitor_kit, event_vendor: jetsin_vendor, company_name: 'Jetsin Berhad', booth_number: 'K2', payment_status: :unpaid) }
  let!(:k3) { create(:exhibitor_kit, event_vendor: jetsin_vendor, company_name: 'Jetsin Berhad', booth_number: 'K3', booking_status: :cancelled) }
  let!(:o1) { create(:exhibitor_kit, event_vendor: other_vendor, company_name: 'Other Co', booth_number: 'O1', payment_status: :paid) }

  def json = JSON.parse(response.body)

  describe 'PATCH :id/tags' do
    it 'records collected tags with who and when' do
      patch "#{base}/#{k1.id}/tags", params: { exhibitor_kit: { tags_collected: 1 } }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include('tags_collected' => 1, 'tags_included' => 2, 'extra_tags' => 0)
      expect(k1.reload.tags_collected_by).to eq(org_owner)
      expect(k1.tags_collected_at).to be_present
    end

    it 'counts tags taken beyond the included ones as extra' do
      patch "#{base}/#{k1.id}/tags", params: { exhibitor_kit: { tags_collected: 5 } }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include('tags_collected' => 5, 'tags_included' => 2, 'extra_tags' => 3)
    end

    it 'rejects negative counts' do
      patch "#{base}/#{k1.id}/tags", params: { exhibitor_kit: { tags_collected: -1 } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not collect for cancelled kits' do
      patch "#{base}/#{k3.id}/tags", params: { exhibitor_kit: { tags_collected: 1 } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'is staff only' do
      patch "#{base}/#{k1.id}/tags", params: { exhibitor_kit: { tags_collected: 1 } },
                                     headers: auth_headers(create(:user, :vendor)), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST bulk_tags' do
    it 'tops ticked kits up to the included count and skips cancelled ones' do
      post "#{base}/bulk_tags", params: { operation: 'collect', kit_ids: [k1.id, k2.id, k3.id] }, headers: headers, as: :json

      expect(json).to include('updated' => 2, 'skipped_cancelled' => 1, 'unpaid' => 1)
      expect(k1.reload.tags_collected).to eq(2)
      expect(k2.reload.tags_collected).to eq(2)
      expect(k3.reload.tags_collected).to eq(0)
    end

    it 'leaves kits that already took extra tags alone' do
      k1.update!(tags_collected: 4)

      post "#{base}/bulk_tags", params: { operation: 'collect', kit_ids: [k1.id] }, headers: headers, as: :json

      expect(json).to include('updated' => 0, 'already_complete' => 1)
      expect(k1.reload.tags_collected).to eq(4)
    end

    it 'applies to every kit matching the filters, not just ticked rows' do
      post "#{base}/bulk_tags", params: { operation: 'collect', filters: { q: 'jetsin' } }, headers: headers, as: :json

      expect(json['updated']).to eq(2)
      expect(o1.reload.tags_collected).to eq(0)
    end

    it 'does not touch kits of other events' do
      foreign = create(:exhibitor_kit, event_vendor: create(:exhibitor, event: create(:event, use_exhibitor_kit: true)))

      post "#{base}/bulk_tags", params: { operation: 'collect', kit_ids: [foreign.id] }, headers: headers, as: :json

      expect(json['updated']).to eq(0)
      expect(foreign.reload.tags_collected).to eq(0)
    end

    it 'resets collected tags to zero and can be undone' do
      k1.update!(tags_collected: 3)
      k2.update!(tags_collected: 1)

      post "#{base}/bulk_tags", params: { operation: 'reset', kit_ids: [k1.id, k2.id, k3.id] }, headers: headers, as: :json

      expect(json['updated']).to eq(2)
      expect(k1.reload.tags_collected).to eq(0)
      expect(k1.tags_collected_by).to be_nil

      post "#{base}/bulk_tags",
           params: { operation: 'restore', items: [{ id: k1.id, tags_collected: 3 }, { id: k2.id, tags_collected: 1 }] },
           headers: headers, as: :json
      expect(k1.reload.tags_collected).to eq(3)
      expect(k2.reload.tags_collected).to eq(1)
    end

    it 'restores previous counts after a collect' do
      post "#{base}/bulk_tags", params: { operation: 'collect', kit_ids: [k1.id, k2.id] }, headers: headers, as: :json
      previous = json['previous']

      post "#{base}/bulk_tags", params: { operation: 'restore', items: previous }, headers: headers, as: :json

      expect(json['restored']).to eq(2)
      expect(k1.reload.tags_collected).to eq(0)
      expect(k1.tags_collected_at).to be_nil
    end

    it 'is staff only' do
      post "#{base}/bulk_tags", params: { operation: 'collect', kit_ids: [k1.id] },
                                headers: auth_headers(create(:user, :vendor)), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET vendors/exhibitor_kits' do
    def list(**params)
      get "/v1/events/#{event.id}/vendors/exhibitor_kits", params: params, headers: headers
      JSON.parse(response.body).map { |row| row['kit']['id'] }
    end

    it 'filters by tags status' do
      k1.update!(tags_collected: 2)
      o1.update!(tags_collected: 1)

      expect(list(tags_status: 'complete')).to eq([k1.id])
      expect(list(tags_status: 'partial')).to eq([o1.id])
      expect(list(tags_status: 'none')).to contain_exactly(k2.id, k3.id)
    end

    it 'treats kits that took extra tags as complete' do
      k1.update!(tags_collected: 4)

      expect(list(tags_status: 'complete')).to eq([k1.id])
    end

    it 'reports totals over every matching kit, with extras counted separately' do
      k1.update!(tags_collected: 3)

      list(q: 'jetsin', per_page: 1)

      # K1 and K2 are live (K3 is cancelled): 2 of 4 included tags collected, 1 extra on top.
      expect(response.headers['X-Tags-Collected']).to eq('2')
      expect(response.headers['X-Tags-Entitled']).to eq('4')
      expect(response.headers['X-Tags-Extra']).to eq('1')
    end
  end

  describe 'event setting' do
    it 'rejects a negative tags per kit' do
      event.exhibitor_tags_per_kit = -1
      expect(event).not_to be_valid
    end
  end
end
