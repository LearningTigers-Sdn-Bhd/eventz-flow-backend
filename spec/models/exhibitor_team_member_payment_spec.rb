# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExhibitorTeamMemberPayment, type: :model do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor) }
  let(:exhibitor) { create(:exhibitor, :with_exhibitor_kit, event: event, vendor: vendor) }
  let(:kit) { exhibitor.exhibitor_kit }

  describe 'validations for payment_gateway source' do
    it 'allows pending status with payment_gateway source and no gateway_payment_id' do
      payment = kit.exhibitor_team_member_payments.new(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: 'razorpay'
      )

      expect(payment).to be_valid
    end

    it 'requires gateway when payment_gateway source' do
      payment = kit.exhibitor_team_member_payments.new(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: nil
      )

      expect(payment).not_to be_valid
      expect(payment.errors[:gateway]).to be_present
    end

    it 'requires gateway_payment_id when payment_gateway and verified' do
      payment = kit.exhibitor_team_member_payments.create!(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: 'razorpay'
      )

      payment.status = :verified
      payment.gateway_payment_id = nil

      expect(payment).not_to be_valid
      expect(payment.errors[:gateway_payment_id]).to be_present
    end

    it 'does not require external_ref for payment_gateway source' do
      payment = kit.exhibitor_team_member_payments.new(
        extra_member_count: 1,
        fee_per_member: 50.0,
        amount: 50.0,
        status: :pending,
        payment_source: :payment_gateway,
        gateway: 'razorpay',
        external_ref: nil
      )

      expect(payment).to be_valid
    end
  end
end
