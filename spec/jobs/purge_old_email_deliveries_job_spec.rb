require 'rails_helper'

RSpec.describe PurgeOldEmailDeliveriesJob do
  before do
    EmailLogSetting.current.update!(retention_days: 100, protected_retention_days: 300, purge_enabled: true)
  end

  it 'deletes nothing while purging is switched off' do
    EmailLogSetting.current.update!(purge_enabled: false)
    old = create(:email_delivery, :delivered, created_at: 150.days.ago)

    expect { described_class.perform_now }.not_to change(EmailDelivery, :count)
    expect(EmailDelivery.exists?(old.id)).to be(true)
  end

  it 'deletes rows past their window and keeps the rest' do
    old = create(:email_delivery, :delivered, created_at: 150.days.ago)
    protected_row = create(:email_delivery, status: 'suppressed', created_at: 150.days.ago)
    recent = create(:email_delivery, :delivered, created_at: 5.days.ago)

    described_class.perform_now

    expect(EmailDelivery.exists?(old.id)).to be(false)
    expect(EmailDelivery.exists?(protected_row.id)).to be(true)
    expect(EmailDelivery.exists?(recent.id)).to be(true)
  end

  it 'detaches a newer resend from an expired original instead of failing on the foreign key' do
    original = create(:email_delivery, :failed, created_at: 150.days.ago)
    resend = create(:email_delivery, :delivered, created_at: 5.days.ago, resend_of: original)

    expect { described_class.perform_now }.not_to raise_error

    expect(EmailDelivery.exists?(original.id)).to be(false)
    expect(resend.reload.resend_of_id).to be_nil
  end
end
