Rails.application.config.after_initialize do
  if Sidekiq.server?
    Sidekiq::Cron::Job.create(
      name: 'Complete ended events - every hour',
      cron: '0 * * * *', # or cron: '5 * * * *'  to runs at :05 past each hour
      class: 'CompleteEndedEventsJob'
    )

    Sidekiq::Cron::Job.create(
      name: 'Cleanup expired sessions - daily at 3am',
      cron: '0 3 * * *',
      class: 'CleanupExpiredSessionsJob'
    )

    Sidekiq::Cron::Job.create(
      name: 'Send event reminders - daily at 9am',
      cron: '0 9 * * *',
      class: 'EventReminderJob'
    )

    Sidekiq::Cron::Job.create(
      name: 'Send pending payment reminders - Mondays at 9am',
      cron: '0 9 * * 1',
      class: 'PendingPaymentReminderJob'
    )

    Sidekiq::Cron::Job.create(
      name: 'Retry email deliveries - every 15 minutes',
      cron: '*/15 * * * *',
      class: 'EmailDeliveryRetryJob'
    )

    Sidekiq::Cron::Job.create(
      name: 'Purge unattached blobs - daily at 4am',
      cron: '0 4 * * *',
      class: 'PurgeUnattachedBlobsJob'
    )
  end
end
