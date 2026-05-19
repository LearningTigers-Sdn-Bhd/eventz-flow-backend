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

      it 'rejects PUT/PATCH/DELETE' do
        expect(key.allows_method?('PUT')).to be false
        expect(key.allows_method?('PATCH')).to be false
        expect(key.allows_method?('DELETE')).to be false
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
