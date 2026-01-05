# spec/models/resource_media_type_spec.rb
require 'rails_helper'

RSpec.describe ResourceMediaType, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should have_many(:resources) }
  end

  describe 'soft-delete functionality' do
    let!(:media_type) { create(:resource_media_type) }

    it 'soft-deletes the record' do
      expect { media_type.soft_delete }.to change { media_type.deleted_at }.from(nil)
    end

    it 'restores the record' do
      media_type.soft_delete
      expect { media_type.restore }.to change { media_type.deleted_at }.to(nil)
    end

    it 'excludes soft-deleted records from default scope' do
      soft_deleted_media_type = create(:resource_media_type)
      soft_deleted_media_type.soft_delete
      expect(ResourceMediaType.all).to include(media_type)
      expect(ResourceMediaType.all).not_to include(soft_deleted_media_type)
    end
  end
end
