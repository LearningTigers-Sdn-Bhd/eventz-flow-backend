# frozen_string_literal: true

# Public registration uploads happen before the ticket exists; abandoned form
# sessions leave unattached blobs behind. Purge anything unattached after 2
# days — longer than any plausible form session.
class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  def perform
    ActiveStorage::Blob.unattached.where(created_at: ..2.days.ago).find_each(&:purge_later)
  end
end
