class SendThankYouEmailsJob < ApplicationJob
  queue_as :mailers

  # Per-event delay (EventEmailSetting#thank_you_delay_minutes, default 2h) lets
  # late check-ins land first. The lookback cap is a second guard (besides the
  # migration backfill) so an old event whose thank_you_sent_at got cleared
  # never mass-mails months later.
  DEFAULT_DELAY_MINUTES = 120
  LOOKBACK = 3.days

  def perform
    now = Time.current
    Event.where(status: %i[published completed], thank_you_sent_at: nil)
         .includes(:event_email_setting)
         .ended_between(now - LOOKBACK, now)
         .find_each { |event| send_for(event) if due?(event, now) }
  end

  # One email per address: several tickets bought under the same email only
  # get a single thank-you (first ticket wins, its public_id goes in the link).
  def self.recipient_scope(event)
    event.tickets
         .where(checked_in: true, waiting_list: false, payment_status: :paid)
         .where.not(attendee_email: [nil, ''])
         .select('DISTINCT ON (LOWER(tickets.attendee_email)) tickets.*')
         .order(Arel.sql('LOWER(tickets.attendee_email), tickets.id'))
  end

  private

  def due?(event, now)
    minutes = event.event_email_setting&.thank_you_delay_minutes || DEFAULT_DELAY_MINUTES
    event.effective_end_date <= now - minutes.minutes
  end

  def send_for(event)
    # Atomic claim so overlapping cron runs can't double-send.
    claimed = Event.where(id: event.id, thank_you_sent_at: nil).update_all(thank_you_sent_at: Time.current)
    return if claimed.zero?

    # DISTINCT ON + find_each don't mix (find_each reorders by id), so load.
    self.class.recipient_scope(event).to_a.each do |ticket|
      EmailDelivery::AuditedDelivery.deliver_later(
        mailer_name: 'ThankYouMailer',
        mailer_action: 'thank_you_email',
        args: [ticket],
        related: ticket,
        dedupe: true,
        metadata: { source: 'thank_you_send', event_id: event.id }
      )
    end
  end
end
