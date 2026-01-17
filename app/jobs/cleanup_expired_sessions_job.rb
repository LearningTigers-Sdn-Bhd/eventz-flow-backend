class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :default

  def perform
    # 1. Delete sessions that have naturally expired
    # (expires_at is in the past)
    expired_count = UserSession.where('expires_at < ?', Time.current).delete_all
    
    # 2. Delete sessions that were manually revoked and are older than 30 days
    # (keeping them for 30 days allows for security auditing/investigation)
    revoked_count = UserSession.where(revoked: true).where('updated_at < ?', 30.days.ago).delete_all

    Rails.logger.info "CleanupExpiredSessionsJob: Deleted #{expired_count} expired and #{revoked_count} old revoked sessions."
  end
end
