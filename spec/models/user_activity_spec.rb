# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActivity, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      activity = described_class.new(
        user: user,
        category: 'ticketing',
        action_name: 'Checked in Attendee / Scanned Ticket',
        http_method: 'PATCH',
        path: '/v1/scan/T123/check_in'
      )
      expect(activity).to be_valid
    end

    it 'validates presence of action_name' do
      activity = described_class.new(user: user, http_method: 'POST', path: '/test')
      expect(activity).not_to be_valid
      expect(activity.errors[:action_name]).to be_present
    end

    it 'validates presence of http_method' do
      activity = described_class.new(user: user, action_name: 'Test', path: '/test')
      expect(activity).not_to be_valid
      expect(activity.errors[:http_method]).to be_present
    end

    it 'validates presence of path' do
      activity = described_class.new(user: user, action_name: 'Test', http_method: 'GET')
      expect(activity).not_to be_valid
      expect(activity.errors[:path]).to be_present
    end
  end

  describe 'scopes' do
    let!(:old_activity) do
      described_class.create!(
        user: user,
        category: 'auth',
        action_name: 'Logged In',
        http_method: 'POST',
        path: '/v1/auth/login',
        created_at: 4.days.ago
      )
    end

    let!(:recent_activity) do
      described_class.create!(
        user: user,
        category: 'ticketing',
        action_name: 'Checked in Attendee',
        http_method: 'PATCH',
        path: '/v1/scan/1/check_in',
        created_at: 1.hour.ago
      )
    end

    describe '.within_days' do
      it 'returns only records within the specified days' do
        results = described_class.within_days(3)
        expect(results).to include(recent_activity)
        expect(results).not_to include(old_activity)
      end
    end

    describe '.cleanup_old_activities!' do
      it 'deletes records older than the specified days' do
        expect {
          described_class.cleanup_old_activities!(3)
        }.to change(described_class, :count).by(-1)

        expect(described_class.exists?(old_activity.id)).to be false
        expect(described_class.exists?(recent_activity.id)).to be true
      end
    end
  end
end
