# spec/models/resource_changelog_spec.rb
require 'rails_helper'

RSpec.describe ResourceChangelog, type: :model do
  describe 'validations' do
    subject { build(:resource_changelog) }

    it { should validate_presence_of(:resource_id) }
    it { should validate_presence_of(:changed_by_user_id) }
    it { should validate_presence_of(:changed_at) }
  end

  describe 'associations' do
    it { should belong_to(:resource) }
    it { should belong_to(:changed_by_user).class_name('User') }
  end

  describe 'scopes' do
    let(:resource) { create(:resource) }
    let(:user) { create(:user) }
    let!(:changelog1) { create(:resource_changelog, resource: resource, changed_at: 2.days.ago) }
    let!(:changelog2) { create(:resource_changelog, resource: resource, changed_at: 1.day.ago) }
    let!(:other_changelog) { create(:resource_changelog, changed_at: 1.day.ago) }

    describe '.for_resource' do
      it 'returns changelogs for a specific resource' do
        changelogs = ResourceChangelog.for_resource(resource)
        expect(changelogs).to include(changelog1, changelog2)
        expect(changelogs).not_to include(other_changelog)
      end
    end

    describe '.recent' do
      it 'orders changelogs by changed_at descending' do
        changelogs = ResourceChangelog.for_resource(resource).recent
        expect(changelogs.first).to eq(changelog2)
        expect(changelogs.last).to eq(changelog1)
      end
    end

    describe '.history_for' do
      it 'returns the changelog history for a resource' do
        history = ResourceChangelog.history_for(resource)
        expect(history.to_a).to eq([changelog2, changelog1])
      end
    end
  end

  describe '#snapshot' do
    let(:changelog) { create(:resource_changelog, title: 'Test Title', article: 'Test Article') }

    it 'returns a hash of the changelog fields' do
      snapshot = changelog.snapshot
      expect(snapshot).to be_a(Hash)
      expect(snapshot[:title]).to eq('Test Title')
      expect(snapshot[:article]).to eq('Test Article')
      expect(snapshot).to have_key(:slug)
      expect(snapshot).to have_key(:status)
      expect(snapshot).to have_key(:published_at)
    end
  end
end
