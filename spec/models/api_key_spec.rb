require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  let(:user) { create(:user, :org_owner) }

  describe '#allows_method?' do
    context 'when scope is read_only' do
      let(:key) { build(:api_key, user: user, scope: 'read_only') }

      it 'allows GET' do
        expect(key.allows_method?('GET')).to be true
      end

      it 'allows HEAD' do
        expect(key.allows_method?('HEAD')).to be true
      end

      it 'rejects POST' do
        expect(key.allows_method?('POST')).to be false
      end

      it 'rejects PUT' do
        expect(key.allows_method?('PUT')).to be false
      end

      it 'rejects PATCH' do
        expect(key.allows_method?('PATCH')).to be false
      end

      it 'rejects DELETE' do
        expect(key.allows_method?('DELETE')).to be false
      end

      it 'is case-insensitive' do
        expect(key.allows_method?('get')).to be true
        expect(key.allows_method?('post')).to be false
      end
    end

    context 'when scope is check_in' do
      let(:key) { build(:api_key, user: user, scope: 'check_in') }

      it 'allows GET' do
        expect(key.allows_method?('GET')).to be true
      end

      it 'allows POST (for /check_in)' do
        expect(key.allows_method?('POST')).to be true
      end

      it 'allows PATCH on /check_in paths' do
        expect(key.allows_method?('PATCH', '/v1/scan/abc/check_in')).to be true
        expect(key.allows_method?('PATCH', '/v1/tickets/check_in')).to be true
        expect(key.allows_method?('PATCH', '/v1/visitors/check_in')).to be true
      end

      it 'allows PATCH on /unscan paths' do
        expect(key.allows_method?('PATCH', '/v1/tickets/123/unscan')).to be true
        expect(key.allows_method?('PATCH', '/v1/visitors/456/unscan')).to be true
      end

      it 'rejects PATCH on non-check-in paths' do
        expect(key.allows_method?('PATCH', '/v1/events/1')).to be false
        expect(key.allows_method?('PATCH', '/v1/tickets/1')).to be false
      end

      it 'rejects PATCH without a path (defensive)' do
        expect(key.allows_method?('PATCH')).to be false
      end

      it 'rejects PUT and DELETE everywhere' do
        expect(key.allows_method?('PUT', '/v1/scan/abc/check_in')).to be false
        expect(key.allows_method?('DELETE', '/v1/scan/abc/check_in')).to be false
      end
    end

    context 'when scope is read_write' do
      let(:key) { build(:api_key, user: user, scope: 'read_write') }

      it 'allows all standard methods' do
        %w[GET HEAD POST PUT PATCH DELETE].each do |method|
          expect(key.allows_method?(method)).to be(true), "expected #{method} to be allowed"
        end
      end
    end
  end

  describe 'rfid keys' do
    let(:event) { create(:event, use_api_access: true) }

    it 'authenticates prefixed RFID key and preserves an old key' do
      old = create(:api_key, user: user, event: event, scope: 'read_only')
      rfid = create(:api_key, user: user, event: event, scope: 'rfid')
      expect(ApiKey.authenticate_by_key(rfid.raw_key)).to eq(rfid)
      expect(ApiKey.authenticate_by_key(old.raw_key)).to eq(old)
      expect(rfid.allows_method?('GET', '/v1/events')).to be(false)
      expect(rfid.allows_method?('POST', '/v1/rfid/desk_scans')).to be(true)
    end

    it 'mints a recognisable prefix and never stores the raw key' do
      key = create(:api_key, user: user, event: event, scope: 'rfid')

      expect(key.raw_key).to match(ApiKey::RFID_KEY_RE)
      expect(key.key_prefix).to eq(key.raw_key[0, ApiKey::RFID_PREFIX_LENGTH])
      expect(key.key_hash).not_to include(key.raw_key)
      expect(ApiKey.active.where(key_prefix: key.key_prefix)).to contain_exactly(key)
    end

    it 'keeps legacy keys on the old generation path' do
      key = create(:api_key, user: user, event: event, scope: 'read_write')

      expect(key.key_prefix).to be_nil
      expect(key.raw_key).to match(/\A[0-9a-f]{64}\z/)
    end

    it 'never falls back to the legacy scan for a prefixed-looking key' do
      legacy = create(:api_key, user: user, event: event, scope: 'read_write')
      lookalike = "rfd_#{'0' * 16}_#{legacy.raw_key}"

      expect(ApiKey.authenticate_by_key(lookalike)).to be_nil
      expect(ApiKey.authenticate_by_key(legacy.raw_key)).to eq(legacy)
    end

    it 'rejects a prefixed key whose secret does not match the prefix row' do
      key = create(:api_key, user: user, event: event, scope: 'rfid')
      tampered = "rfd_#{'a' * 16}_#{key.raw_key.split('_').last}"

      expect(ApiKey.authenticate_by_key(tampered)).to be_nil
      expect(ApiKey.authenticate_by_key("rfd_#{key.key_prefix[4..]}_#{'0' * 64}")).to be_nil
    end

    it 'stops authenticating a revoked rfid key and only touches last_used_at on a match' do
      key = create(:api_key, user: user, event: event, scope: 'rfid')
      expect(key.last_used_at).to be_nil

      expect(ApiKey.authenticate_by_key(key.raw_key)).to eq(key)
      expect(key.reload.last_used_at).to be_present

      key.revoke!
      expect(ApiKey.authenticate_by_key(key.raw_key)).to be_nil
    end

    it 'allows exactly the seven device routes and no other path or method' do
      key = build(:api_key, user: user, event: event, scope: 'rfid')

      ApiKey::RFID_ROUTES.each do |route|
        method, path = route.split(' ')
        expect(key.allows_method?(method, path)).to be(true), "expected #{route} to be allowed"
      end

      expect(key.allows_method?('GET', '/v1/rfid/cache')).to be(true)
      expect(key.allows_method?('DELETE', '/v1/rfid/cache')).to be(false)
      expect(key.allows_method?('PATCH', '/v1/rfid/observations')).to be(false)
      expect(key.allows_method?('GET', '/v1/rfid/tickets/search/1')).to be(false)
      expect(key.allows_method?('GET', '/v1/events/1/rfid/summary')).to be(false)
      expect(key.allows_method?('GET', '/v1/events')).to be(false)
      expect(key.allows_method?('GET', '/v1/rfid/unknown')).to be(false)
    end
  end

  describe 'validations' do
    it 'rejects unknown scope values' do
      key = build(:api_key, user: user, scope: 'admin')
      expect(key).not_to be_valid
      expect(key.errors[:scope]).to be_present
    end

    it 'requires scope' do
      key = build(:api_key, user: user, scope: nil)
      expect(key).not_to be_valid
      expect(key.errors[:scope]).to be_present
    end
  end
end
