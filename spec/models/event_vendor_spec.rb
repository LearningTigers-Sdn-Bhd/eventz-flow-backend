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

  describe 'Exhibitor active booking scope' do
    let(:event) { create(:event) }
    let!(:active_exhibitor) { create(:exhibitor, :with_exhibitor_kit, event: event) }
    let!(:paid_exhibitor) { create(:exhibitor, :with_exhibitor_kit, event: event) }
    let!(:cancelled_exhibitor) { create(:exhibitor, :with_exhibitor_kit, event: event) }
    let!(:exhibitor_without_kit) { create(:exhibitor, event: event) }

    before do
      paid_exhibitor.exhibitor_kits.update_all(booking_status: ExhibitorKit.booking_statuses[:paid])
      cancelled_exhibitor.exhibitor_kits.update_all(booking_status: ExhibitorKit.booking_statuses[:cancelled])
    end

    it 'returns exhibitors with at least one active or paid kit' do
      expect(Exhibitor.where(event: event).with_active_kit).to contain_exactly(active_exhibitor, paid_exhibitor)
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
    it { should have_many(:event_leads).dependent(:destroy) }
  end

  describe 'Exhibitor specific associations and validations' do
    let(:event) { create(:event, use_ticket: true) }
    let(:vendor_user) { create(:user, :vendor) }
    let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor_user) }

    it 'has many ordered exhibitor_kits' do
      expect(exhibitor).to have_many(:exhibitor_kits).dependent(:destroy).with_foreign_key(:event_vendor_id)
    end

    it 'has many exhibitor_team_members through exhibitor_kits' do
      expect(exhibitor).to have_many(:exhibitor_team_members).through(:exhibitor_kits)
    end

    it 'retains multiple kits in creation order and returns the oldest for legacy reads' do
      newer_kit = create(:exhibitor_kit, event_vendor: exhibitor, created_at: 1.hour.ago)
      older_kit = create(:exhibitor_kit, event_vendor: exhibitor, created_at: 2.hours.ago)

      expect(exhibitor.exhibitor_kits).to eq([older_kit, newer_kit])
      expect(exhibitor.legacy_exhibitor_kit).to eq(older_kit)
      expect(exhibitor.exhibitor_kit).to eq(older_kit)
    end

    it 'destroys all kits when the exhibitor is destroyed' do
      create_list(:exhibitor_kit, 2, event_vendor: exhibitor)

      expect { exhibitor.destroy! }.to change(ExhibitorKit, :count).by(-2)
    end

    it 'aggregates team members from every kit' do
      kits = create_list(:exhibitor_kit, 2, event_vendor: exhibitor)

      expect(exhibitor.exhibitor_team_members).to match_array(kits.flat_map(&:exhibitor_team_members))
    end

    it 'accepts plural nested kit attributes' do
      exhibitor = build(:exhibitor)
      exhibitor.exhibitor_kits_attributes = [attributes_for(:exhibitor_kit)]

      expect(exhibitor.exhibitor_kits.size).to eq(1)
    end

    it 'allows an exhibitor with no kits' do
      exhibitor = create(:exhibitor)

      expect(exhibitor).to be_valid
      expect(exhibitor.exhibitor_kits).to be_empty
    end
  end
end
