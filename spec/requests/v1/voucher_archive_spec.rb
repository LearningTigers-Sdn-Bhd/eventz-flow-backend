require 'rails_helper'

RSpec.describe 'V1 voucher archive / restore / force delete', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:vendor) { create(:user, :vendor) }
  let(:event) { create(:event, use_voucher: true) }
  let!(:voucher) { create(:voucher, vendor: vendor, event: event) }

  def headers_for(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  describe 'DELETE /v1/vouchers/:id (archive)' do
    it 'archives instead of deleting and hides it from the default list' do
      delete "/v1/vouchers/#{voucher.id}", headers: headers_for(organizer)

      expect(response).to have_http_status(:ok)
      expect(Voucher.only_deleted.find(voucher.id).deleted_at).to be_present

      get '/v1/vouchers', params: { event_id: event.id }, headers: headers_for(owner)
      expect((JSON.parse(response.body)['data'] || []).pluck('id')).not_to include(voucher.id)
    end

    it 'lists archived vouchers with archived=true' do
      voucher.archive

      get '/v1/vouchers', params: { event_id: event.id, archived: true }, headers: headers_for(owner)
      expect(JSON.parse(response.body)['data'].pluck('id')).to eq([voucher.id])
    end

    it 'only lets a vendor list their own archived vouchers' do
      voucher.archive
      other = create(:user, :vendor)

      get '/v1/vouchers', params: { event_id: event.id, archived: true }, headers: headers_for(other)
      expect(JSON.parse(response.body)['data'] || []).to be_empty

      get '/v1/vouchers', params: { event_id: event.id, archived: true }, headers: headers_for(vendor)
      expect(JSON.parse(response.body)['data'].pluck('id')).to eq([voucher.id])
    end

    it 'rejects unauthenticated archived listing' do
      voucher.archive

      get '/v1/vouchers', params: { event_id: event.id, archived: true }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'no longer redeems or shows an archived voucher publicly' do
      voucher.archive
      expect(Voucher.find_by(voucher_uuid: voucher.voucher_uuid)).to be_nil

      get "/v1/public/vouchers/#{voucher.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /v1/vouchers/:id/restore' do
    before { voucher.archive }

    it 'restores for an organizer' do
      patch "/v1/vouchers/#{voucher.id}/restore", headers: headers_for(organizer)

      expect(response).to have_http_status(:ok)
      expect(Voucher.find_by(id: voucher.id)).to be_present
    end

    it 'forbids another vendor' do
      patch "/v1/vouchers/#{voucher.id}/restore", headers: headers_for(create(:user, :vendor))

      expect(response).to have_http_status(:forbidden)
      expect(Voucher.find_by(id: voucher.id)).to be_nil
    end
  end

  describe 'DELETE /v1/vouchers/:id/force_delete' do
    it 'permanently deletes for the org owner, redemption history included' do
      create(:voucher_usage, voucher: voucher)
      voucher.archive

      expect do
        delete "/v1/vouchers/#{voucher.id}/force_delete", headers: headers_for(owner)
      end.to change { Voucher.with_deleted.count }.by(-1).and change(VoucherUsage, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'forbids organizers and vendors' do
      [organizer, vendor].each do |user|
        delete "/v1/vouchers/#{voucher.id}/force_delete", headers: headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
      expect(Voucher.find_by(id: voucher.id)).to be_present
    end
  end

  it 'keeps the voucher reachable from its redemption log after archive' do
    log = create(:voucher_redemption_log, voucher: voucher)
    voucher.archive

    expect(log.reload.voucher).to eq(voucher)
  end
end
