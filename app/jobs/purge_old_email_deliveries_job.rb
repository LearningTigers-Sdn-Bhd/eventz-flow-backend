class PurgeOldEmailDeliveriesJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1_000

  def perform
    setting = EmailLogSetting.current
    return unless setting.purge_enabled

    purged = 0
    setting.purgeable.in_batches(of: BATCH_SIZE) do |batch|
      ids = batch.pluck(:id)
      # resend_of_id is a self-referencing FK: detach newer resends first.
      EmailDelivery.where(resend_of_id: ids).update_all(resend_of_id: nil)
      purged += EmailDelivery.where(id: ids).delete_all
    end

    Rails.logger.info "PurgeOldEmailDeliveriesJob: deleted #{purged} email deliveries past retention."
  end
end
