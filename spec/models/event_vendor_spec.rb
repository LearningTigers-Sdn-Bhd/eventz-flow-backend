# spec/models/event_vendor_spec.rb

require 'rails_helper'

RSpec.describe EventVendor, type: :model do
  describe 'STI behavior' do
    let(:event) { create(:event, use_ticket: true) }
    let(:vendor) { create(:user, :vendor) }

    it 'creates Exhibitor when type is set to Exhibitor' do
      exhibitor = EventVendor.create!(
        type: 'Exhibitor',
        event: event,
        vendor: vendor,
        redirect_url: 'https://example.com'
      )

      expect(exhibitor).to be_an(Exhibitor)
      expect(exhibitor.type).to eq('Exhibitor')
    end

    it 'creates Merchant when type is set to Merchant' do
      merchant = EventVendor.create!(
        type: 'Merchant',
        event: event,
        vendor: vendor,
        redirect_url: 'https://example.com'
      )

      expect(merchant).to be_a(Merchant)
      expect(merchant.type).to eq('Merchant')
    end
  end

  describe 'scopes' do
    let!(:exhibitor) { create(:exhibitor) }
    let!(:merchant) { create(:merchant) }

    it 'returns only exhibitors with exhibitors scope' do
      expect(EventVendor.exhibitors).to include(exhibitor)
      expect(EventVendor.exhibitors).not_to include(merchant)
    end

    it 'returns only merchants with merchants scope' do
      expect(EventVendor.merchants).to include(merchant)
      expect(EventVendor.merchants).not_to include(exhibitor)
    end
  end

  describe '.create_for_event' do
    let(:vendor) { create(:user, :vendor) }

    context 'when event.use_ticket is true' do
      let(:event) { create(:event, use_ticket: true) }

      it 'creates an Exhibitor' do
        event_vendor = EventVendor.create_for_event(
          event,
          vendor,
          redirect_url: 'https://example.com'
        )

        expect(event_vendor).to be_an(Exhibitor)
        expect(event_vendor.type).to eq('Exhibitor')
      end
    end

    context 'when event.use_ticket is false' do
      let(:event) { create(:event, use_ticket: false) }

      it 'creates a Merchant' do
        event_vendor = EventVendor.create_for_event(
          event,
          vendor,
          redirect_url: 'https://example.com'
        )

        expect(event_vendor).to be_a(Merchant)
        expect(event_vendor.type).to eq('Merchant')
      end
    end
  end

  describe 'validations' do
    let(:event) { create(:event) }
    let(:vendor) { create(:user, :vendor) }
    subject { build(:merchant, event: event, vendor: vendor, redirect_url: 'https://example.com') }

    it { should validate_presence_of(:event_id) }
    it { should validate_presence_of(:vendor_id) }
    it { should validate_uniqueness_of(:vendor_id).scoped_to(:event_id).with_message('already exists for this event') }
  end

  describe 'associations' do
    it { should belong_to(:event) }
    it { should belong_to(:vendor).class_name('User') }
    it { should have_many(:visitor_vendor_stamps).dependent(:destroy) }
  end

  describe 'Exhibitor specific associations and validations' do
    let(:event) { create(:event, use_ticket: true) }
    let(:vendor_user) { create(:user, :vendor) }
    let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }

    it 'has one exhibitor_kit' do
      expect(exhibitor).to have_one(:exhibitor_kit).dependent(:destroy).with_foreign_key(:event_vendor_id)
    end

    it 'has many exhibitor_team_members through exhibitor_kit' do
      expect(exhibitor).to have_many(:exhibitor_team_members).through(:exhibitor_kit)
    end

    it 'validates presence of exhibitor_kit on creation in production' do
      pending 'This validation is conditional to Rails.env.production?'
      exhibitor_without_kit = build(:exhibitor, event: event, vendor: vendor_user, exhibitor_kit: nil)
      expect(exhibitor_without_kit).not_to be_valid
      expect(exhibitor_without_kit.errors[:exhibitor_kit]).to include("must exist")
    end
  end
end
