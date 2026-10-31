# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GuestPassResizer do
  let(:event) { create(:event) }
  let(:ticket_type) { create(:ticket_type, event: event, quantity: 100) }
  let(:batch_id) { SecureRandom.uuid }

  def create_pack(total)
    Array.new(total) do |i|
      create(:ticket, event: event, ticket_type: ticket_type,
                      attendee_name: "Acme Sdn Bhd Pax #{i + 1}/#{total}", guest_pass_label: 'Acme Sdn Bhd',
                      attendee_email: nil, attendee_phone: nil, role: 'Sponsor Guest',
                      payment_status: :paid, registration_batch_id: batch_id)
    end
  end

  def resize(quantity, can_remove: true)
    described_class.call(event, batch_id: batch_id, quantity: quantity, can_remove: can_remove)
  end

  def active_names
    event.tickets.where(registration_batch_id: batch_id).order(:id).pluck(:attendee_name)
  end

  describe 'growing' do
    it 'adds passes to the same batch and keeps existing tickets and QR ids' do
      original = create_pack(3)

      result = resize(5)

      expect(result).to be_success
      expect(result.added.size).to eq(2)
      expect(event.tickets.where(registration_batch_id: batch_id).pluck(:public_id)).to include(*original.map(&:public_id))
      expect(active_names).to eq((1..5).map { |i| "Acme Sdn Bhd Pax #{i}/5" })
      expect(result.added.map(&:guest_pass_label).uniq).to eq(['Acme Sdn Bhd'])
      expect(result.added.map(&:role).uniq).to eq(['Sponsor Guest'])
    end

    it 'refuses when the ticket type lacks capacity' do
      ticket_type.update!(quantity: 4)
      create_pack(3)

      result = resize(6)

      expect(result.status).to eq(:unprocessable_content)
      expect(result.errors.first).to match(/Not enough capacity/)
      expect(active_names.size).to eq(3)
    end
  end

  describe 'shrinking' do
    it 'archives the highest-numbered placeholder passes and renumbers the rest' do
      pack = create_pack(5)

      result = resize(3)

      expect(result).to be_success
      expect(result.removed.map(&:public_id)).to match_array(pack.last(2).map(&:public_id))
      expect(active_names).to eq((1..3).map { |i| "Acme Sdn Bhd Pax #{i}/3" })
    end

    it 'never removes checked-in or renamed passes' do
      pack = create_pack(4)
      pack[3].update_columns(checked_in: true)
      pack[2].update_columns(attendee_name: 'Real Person')

      result = resize(1)

      expect(result.status).to eq(:unprocessable_content)
      expect(result.errors.first).to match(/Can only remove 2 of 3/)
      expect(active_names.size).to eq(4)
    end

    it 'is forbidden without remove rights' do
      create_pack(4)

      result = resize(2, can_remove: false)

      expect(result.status).to eq(:forbidden)
      expect(active_names.size).to eq(4)
    end
  end

  it 'reports an unknown batch' do
    expect(resize(3).status).to eq(:not_found)
  end

  it 'rejects an out of range quantity' do
    create_pack(2)

    expect(resize(0).status).to eq(:unprocessable_content)
    expect(resize(501).status).to eq(:unprocessable_content)
  end
end
