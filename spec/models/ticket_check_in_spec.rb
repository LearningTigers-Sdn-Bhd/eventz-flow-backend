require 'rails_helper'

RSpec.describe TicketCheckIn, type: :model do
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) { create(:ticket, event: event, ticket_type: ticket_type) }
  let(:user) { create(:user) }

  describe 'associations' do
    it { should belong_to(:ticket) }
    it { should belong_to(:scanned_by).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:check_in_at) }

    describe 'unique per day' do
      it 'allows creating the first check-in' do
        check_in = TicketCheckIn.new(ticket: ticket, check_in_at: Time.current)
        expect(check_in).to be_valid
      end

      it 'prevents duplicate check-ins on the same day' do
        create(:ticket_check_in, ticket: ticket, check_in_at: Time.current.beginning_of_day + 10.hours)

        duplicate = TicketCheckIn.new(ticket: ticket, check_in_at: Time.current.beginning_of_day + 14.hours)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:ticket]).to include('already checked in today')
      end

      it 'allows check-ins on different days' do
        create(:ticket_check_in, ticket: ticket, check_in_at: 1.day.ago)

        today_check_in = TicketCheckIn.new(ticket: ticket, check_in_at: Time.current)
        expect(today_check_in).to be_valid
      end
    end
  end

  describe 'creation' do
    it 'creates a valid check-in record' do
      check_in = TicketCheckIn.create!(
        ticket: ticket,
        check_in_at: Time.current,
        scanned_by: user
      )

      expect(check_in).to be_persisted
      expect(check_in.ticket).to eq(ticket)
      expect(check_in.scanned_by).to eq(user)
    end

    it 'allows check-in without scanned_by (public check-in)' do
      check_in = TicketCheckIn.create!(
        ticket: ticket,
        check_in_at: Time.current,
        scanned_by: nil
      )

      expect(check_in).to be_persisted
      expect(check_in.scanned_by).to be_nil
    end
  end
end
