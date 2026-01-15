# spec/models/resource_category_spec.rb
require 'rails_helper'

RSpec.describe ResourceCategory, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should have_many(:resources) }
  end

  describe 'soft-delete functionality' do
    let!(:category) { create(:resource_category) }

    it 'soft-deletes the record' do
      expect { category.soft_delete }.to change { category.deleted_at }.from(nil)
    end

    it 'restores the record' do
      category.soft_delete
      expect { category.restore }.to change { category.deleted_at }.to(nil)
    end

    it 'excludes soft-deleted records from default scope' do
      soft_deleted_category = create(:resource_category)
      soft_deleted_category.soft_delete
      expect(ResourceCategory.all).to include(category)
      expect(ResourceCategory.all).not_to include(soft_deleted_category)
    end
  end
end
