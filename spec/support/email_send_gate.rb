RSpec.configure do |config|
  config.before do
    # Mail uses the test adapter; gate specs opt into the Redis implementation explicitly.
    allow(EmailDelivery::AuditedDelivery).to receive(:wait_for_send_slot)
  end
end
