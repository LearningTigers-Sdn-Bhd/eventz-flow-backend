require 'rails_helper'

RSpec.describe EventReminderLog, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should belong_to(:ticket) }
  end

  describe 'validations' do
    let(:event) { create(:event) }
    let(:ticket) { create(:ticket, event: event) }

    subject { create(:event_reminder_log, event: event, ticket: ticket) }

    it { should validate_presence_of(:reminder_type) }
    it { should validate_inclusion_of(:reminder_type).in_array(%w[7_day 1_day]) }
    it { should validate_inclusion_of(:status).in_array(%w[sent failed]) }
    it { should validate_uniqueness_of(:ticket_id).scoped_to(:reminder_type) }
  end
end
