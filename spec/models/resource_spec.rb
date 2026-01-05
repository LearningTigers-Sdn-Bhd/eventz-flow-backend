# spec/models/resource_spec.rb
require 'rails_helper'

RSpec.describe Resource, type: :model do
  describe 'validations' do
    # Create a resource before running the validation specs
    subject { create(:resource) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:resource_topic) }
    it { should belong_to(:resource_category) }
    it { should belong_to(:resource_media_type) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, in_review: 1, published: 2) }
  end

  describe 'callbacks' do
    context 'on create' do
      it 'generates a slug from the title if slug is not provided' do
        resource = build(:resource, title: 'A Great New Post!', slug: nil)
        resource.valid? # trigger before_validation callbacks
        expect(resource.slug).to eq('a-great-new-post')
      end

      it 'does not overwrite an existing slug' do
        resource = build(:resource, title: 'A Great New Post!', slug: 'my-custom-slug')
        resource.valid?
        expect(resource.slug).to eq('my-custom-slug')
      end
    end
  end

  describe 'soft-delete functionality' do
    let!(:resource) { create(:resource) }

    it 'soft-deletes the record' do
      expect { resource.soft_delete }.to change { resource.deleted_at }.from(nil)
    end

    it 'restores the record' do
      resource.soft_delete
      expect { resource.restore }.to change { resource.deleted_at }.to(nil)
    end

    it 'excludes soft-deleted records from default scope' do
      soft_deleted_resource = create(:resource)
      soft_deleted_resource.soft_delete
      expect(Resource.all).to include(resource)
      expect(Resource.all).not_to include(soft_deleted_resource)
    end
  end
end
