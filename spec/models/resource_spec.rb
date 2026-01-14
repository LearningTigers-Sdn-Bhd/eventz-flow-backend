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
    it { should have_many(:resource_changelogs).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, pending_review: 1, published: 2, rejected: 4) }
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

  describe 'scopes' do
    describe '.featured' do
      it 'returns only resources with priority 1' do
        featured1 = create(:resource, priority: 1)
        featured2 = create(:resource, priority: 1)
        standard = create(:resource, priority: 2)

        featured_resources = Resource.featured
        expect(featured_resources).to include(featured1, featured2)
        expect(featured_resources).not_to include(standard)
      end
    end

    describe '.standard' do
      it 'returns only resources with priority 2-5' do
        featured = create(:resource, priority: 1)
        standard1 = create(:resource, priority: 2)
        standard2 = create(:resource, priority: 3)
        standard3 = create(:resource, priority: 5)
        low_priority = create(:resource, priority: 6)

        standard_resources = Resource.standard
        expect(standard_resources).to include(standard1, standard2, standard3)
        expect(standard_resources).not_to include(featured, low_priority)
      end
    end

    describe '.published' do
      it 'returns only published resources' do
        published = create(:resource, status: :published)
        draft = create(:resource, status: :draft)

        expect(Resource.published).to include(published)
        expect(Resource.published).not_to include(draft)
      end
    end
  end

  describe '.featured_page_resources' do
    before do
      # Create featured resources (priority 1)
      create_list(:resource, 5, status: :published, priority: 1)
      # Create standard resources (priority 2-5)
      create_list(:resource, 8, status: :published, priority: 2)
      create_list(:resource, 3, status: :published, priority: 4)
      # Create draft resources (should not be included)
      create(:resource, status: :draft, priority: 1)
      create(:resource, status: :draft, priority: 2)
    end

    it 'returns a hash with featured and standard keys' do
      result = Resource.featured_page_resources
      expect(result).to be_a(Hash)
      expect(result).to have_key(:featured)
      expect(result).to have_key(:standard)
    end

    it 'returns maximum 3 featured resources with priority 1' do
      featured = Resource.featured_page_resources[:featured]
      expect(featured.size).to eq(3)
      expect(featured.all? { |r| r.priority == 1 }).to be true
      expect(featured.all? { |r| r.status == 'published' }).to be true
    end

    it 'returns maximum 6 standard resources with priority 2-5' do
      standard = Resource.featured_page_resources[:standard]
      expect(standard.size).to eq(6)
      expect(standard.all? { |r| r.priority.between?(2, 5) }).to be true
      expect(standard.all? { |r| r.status == 'published' }).to be true
    end

    it 'orders resources by published_at desc, then created_at desc' do
      # Clear existing featured resources to isolate this test
      Resource.where(priority: 1).destroy_all

      # Create resources with specific timestamps
      oldest = create(:resource, status: :published, priority: 1, published_at: 3.days.ago)
      newest = create(:resource, status: :published, priority: 1, published_at: 1.day.ago)
      middle = create(:resource, status: :published, priority: 1, published_at: 2.days.ago)

      featured = Resource.featured_page_resources[:featured]
      expect(featured.size).to eq(3)
      expect(featured.first.id).to eq(newest.id)
      expect(featured[1].id).to eq(middle.id)
      expect(featured[2].id).to eq(oldest.id)
    end

    it 'does not include draft resources' do
      result = Resource.featured_page_resources
      all_resources = result[:featured].to_a + result[:standard].to_a
      expect(all_resources.none? { |r| r.status == 'draft' }).to be true
    end
  end

  describe 'changelog functionality' do
    let(:user) { create(:user) }
    let(:resource) { create(:resource, status: :published, title: 'Original Title', article: 'Original content') }

    context 'when updating a published resource' do
      it 'creates a changelog entry when current_user_for_changelog is set' do
        resource.current_user_for_changelog = user

        expect {
          resource.update!(title: 'Updated Title')
        }.to change { ResourceChangelog.count }.by(1)

        changelog = ResourceChangelog.last
        expect(changelog.resource_id).to eq(resource.id)
        expect(changelog.changed_by_user_id).to eq(user.id)
        expect(changelog.title).to eq('Original Title')
        expect(changelog.changed_at).to be_present
      end

      it 'does not create a changelog entry when current_user_for_changelog is not set' do
        expect {
          resource.update!(title: 'Updated Title')
        }.not_to change { ResourceChangelog.count }
      end

      it 'captures all resource fields in the changelog' do
        resource.current_user_for_changelog = user

        resource.update!(
          title: 'New Title',
          article: 'New content',
          meta_description: 'New description'
        )

        changelog = ResourceChangelog.last
        expect(changelog.title).to eq('Original Title')
        expect(changelog.article).to eq('Original content')
        expect(changelog.slug).to eq(resource.slug)
        expect(changelog.resource_topic_id).to eq(resource.resource_topic_id)
        expect(changelog.resource_category_id).to eq(resource.resource_category_id)
      end
    end

    context 'when updating a draft resource' do
      let(:draft_resource) { create(:resource, status: :draft, title: 'Draft Title') }

      it 'does not create a changelog entry' do
        draft_resource.current_user_for_changelog = user

        expect {
          draft_resource.update!(title: 'Updated Draft Title')
        }.not_to change { ResourceChangelog.count }
      end
    end

    context 'when transitioning from draft to published' do
      let(:draft_resource) { create(:resource, status: :draft) }

      it 'does not create a changelog entry on first publish' do
        draft_resource.current_user_for_changelog = user

        expect {
          draft_resource.update!(status: :published, published_at: Time.current)
        }.not_to change { ResourceChangelog.count }
      end
    end

    context 'when unpublishing a resource' do
      it 'creates a changelog entry capturing the published state' do
        resource.current_user_for_changelog = user

        expect {
          resource.update!(status: :draft)
        }.to change { ResourceChangelog.count }.by(1)

        changelog = ResourceChangelog.last
        expect(changelog.status).to eq(Resource.statuses[:published])
      end
    end
  end
end
