# spec/models/resource_topic_spec.rb
require 'rails_helper'

RSpec.describe ResourceTopic, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should have_many(:resources) }
  end

  describe 'soft-delete functionality' do
    let!(:topic) { create(:resource_topic) }

    it 'soft-deletes the record' do
      expect { topic.soft_delete }.to change { topic.deleted_at }.from(nil)
    end

    it 'restores the record' do
      topic.soft_delete
      expect { topic.restore }.to change { topic.deleted_at }.to(nil)
    end

    it 'excludes soft-deleted records from default scope' do
      soft_deleted_topic = create(:resource_topic)
      soft_deleted_topic.soft_delete
      expect(ResourceTopic.all).to include(topic)
      expect(ResourceTopic.all).not_to include(soft_deleted_topic)
    end

    it 'includes soft-deleted records when unscoped' do
      soft_deleted_topic = create(:resource_topic)
      soft_deleted_topic.soft_delete
      expect(ResourceTopic.unscoped.all).to include(topic, soft_deleted_topic)
    end
  end
end
