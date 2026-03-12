# spec/models/merchant_spec.rb

require 'rails_helper'

RSpec.describe Merchant, type: :model do
  describe 'inheritance' do
    it 'inherits from EventVendor' do
      expect(Merchant.superclass).to eq(EventVendor)
    end
  end

  describe 'associations' do
    it { should belong_to(:event) }
    it { should belong_to(:vendor).class_name('User') }
    it { should have_many(:event_leads).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:event_id) }
    it { should validate_presence_of(:vendor_id) }
  end

  describe 'STI behavior' do
    let(:merchant) { create(:merchant) }

    it 'has type Merchant' do
      expect(merchant.type).to eq('Merchant')
    end

    it 'is an instance of Merchant' do
      expect(merchant).to be_a(Merchant)
    end

    it 'is an instance of EventVendor' do
      expect(merchant).to be_a(EventVendor)
    end
  end
end
