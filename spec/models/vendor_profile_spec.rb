# spec/models/vendor_profile_spec.rb
require 'rails_helper'

RSpec.describe VendorProfile, type: :model do
  # --- Setup ---
  let(:vendor) { create(:user, role: :vendor) }
  let(:valid_vendor_profile) { vendor.reload.vendor_profile }

  # --- Associations ---
  describe 'Associations' do
    it { is_expected.to belong_to(:vendor).class_name('User') }
    
    # Note: event_vendors association is scoped by vendor_id
    it 'has many event_vendors scoped to vendor' do
      profile = vendor.reload.vendor_profile
      expect(profile.event_vendors).to respond_to(:each)
    end
  end

  # --- Validations ---
  describe 'Validations' do
    subject { valid_vendor_profile }

    it { is_expected.to validate_presence_of(:vendor_id) }
    
    it 'validates vendor must have vendor role' do
      non_vendor = create(:user, role: :organizer)
      profile = build(:vendor_profile, vendor: non_vendor)
      expect(profile).not_to be_valid
      expect(profile.errors[:vendor]).to include('must have vendor role')
    end
  end

  # --- Uniqueness ---
  describe 'Uniqueness' do
    it 'validates uniqueness of vendor_id' do
      # Profile already created by callback
      existing_profile = vendor.reload.vendor_profile
      expect(existing_profile).to be_present
      
      duplicate = build(:vendor_profile, vendor: vendor)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:vendor_id]).to include('already has a profile')
    end

    it 'allows different vendors to have profiles' do
      # First vendor profile already created by callback
      expect(vendor.reload.vendor_profile).to be_present
      
      # Create another vendor - profile will be auto-created
      other_vendor = create(:user, role: :vendor)
      expect(other_vendor.reload.vendor_profile).to be_present
      expect(other_vendor.vendor_profile).to be_valid
    end
  end

  # --- Fields ---
  describe 'Fields' do
    it 'stores vendor business information' do
      profile = vendor.reload.vendor_profile
      profile.update!(
        description: 'Test description',
        category: 'Technology',
        person_in_charge: 'Jane Doe',
        address: '456 Test St',
        notes: 'Test notes'
      )

      expect(profile.description).to eq('Test description')
      expect(profile.category).to eq('Technology')
      expect(profile.person_in_charge).to eq('Jane Doe')
      expect(profile.address).to eq('456 Test St')
      expect(profile.notes).to eq('Test notes')
    end
  end

  # --- Active Storage ---
  describe 'Active Storage' do
    it { is_expected.to have_one_attached(:image) }

    it 'can attach an image' do
      profile = vendor.reload.vendor_profile
      profile.image.attach(
        io: StringIO.new('fake image data'),
        filename: 'test.jpg',
        content_type: 'image/jpeg'
      )
      expect(profile.image).to be_attached
    end
  end
end
