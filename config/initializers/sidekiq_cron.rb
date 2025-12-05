Rails.application.config.after_initialize do
  if Sidekiq.server?
    Sidekiq::Cron::Job.create(
      name: 'Complete ended events - every hour',
      cron: '0 * * * *', # or cron: '5 * * * *'  to runs at :05 past each hour
      class: 'CompleteEndedEventsJob'
    )
  end
end
