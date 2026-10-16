require 'caxlsx'

# Every email sent for an event as an Excel workbook an organizer can work
# through: a summary, the full list, then one sheet per outcome (what needs
# attention first). Plain words instead of status codes, one row per email.
# Look and feel come from the RFID report's SheetKit.
class EmailDelivery::StatusReportWorkbook
  Kit = Rfid::ReportWorkbook::SheetKit

  # status => [label, chip tone]
  OUTCOMES = {
    'delivered' => ['Delivered', :good], 'sent' => ['Sent', :info],
    'queued' => ['Pending', nil], 'sending' => ['Pending', nil],
    'bounced' => ['Bounced', :warn], 'suppressed' => ['Invalid address', :bad],
    'complained' => ['Marked as spam', :bad], 'failed' => ['Failed', :bad]
  }.freeze

  REASONS = {
    'bounced' => 'The mailbox rejected the email',
    'suppressed' => 'This address previously bounced or blocked us',
    'complained' => 'Recipient marked it as spam',
    'failed' => "We couldn't send this email"
  }.freeze

  EMAIL_TYPES = {
    'confirmation_email' => 'Ticket confirmation', 'payment_pending_email' => 'Payment reminder',
    'group_confirmation_email' => 'Group confirmation', 'voucher_showcase_email' => 'Voucher',
    'business_matching_email' => 'Business matching', 'host_invitation_email' => 'Host invitation email'
  }.freeze

  COLUMNS = [
    Kit::Column.new('Attendee', 28, :text), Kit::Column.new('Email address', 36, :text),
    Kit::Column.new('Phone', 18, :text), Kit::Column.new('Email', 24, :text),
    Kit::Column.new('Status', 18, :text), Kit::Column.new('What happened', 40, :text),
    Kit::Column.new('What to do', 36, :text), Kit::Column.new('Sent at', 20, :time),
    Kit::Column.new('Delivered at', 20, :time)
  ].freeze

  SUMMARY_COLUMNS = [
    Kit::Column.new('Outcome', 30, :text), Kit::Column.new('Emails', 12, :int), Kit::Column.new('Share', 12, :pct)
  ].freeze

  # One sheet per outcome after the full list: [sheet name, title, statuses, empty message].
  STATUS_SHEETS = [
    ['Needs Attention', 'Emails that did not arrive', EmailDelivery::PROBLEM_STATUSES,
     'No problem emails. Everything sent so far reached its destination.'],
    ['Sent', 'Sent, awaiting confirmation', %w[sent], 'Nothing is waiting for confirmation.'],
    ['Delivered', 'Delivered emails', %w[delivered], 'Nothing has been confirmed delivered yet.'],
    ['Pending', 'Emails not sent yet', %w[queued sending], 'Nothing is waiting to be sent.']
  ].freeze

  # `deliveries` are all the event's emails (related records preloaded).
  def initialize(event, deliveries:, now: Time.current)
    @event = event
    @deliveries = deliveries.to_a
    @now = now
  end

  def filename
    "email-status-event-#{@event.id}.xlsx"
  end

  # The .xlsx file contents.
  def call
    package = Axlsx::Package.new(author: 'EventzFlow')
    kit = Kit.new(package)
    summary_sheet(kit)
    list_sheet(kit, 'All Emails', 'Every email for this event', @deliveries, tab: Kit::BLUE)
    STATUS_SHEETS.each do |name, title, statuses, empty|
      rows = @deliveries.select { |delivery| statuses.include?(delivery.status) }
      next if rows.empty? && name != 'Needs Attention'

      list_sheet(kit, name, title, rows, tab: name == 'Needs Attention' ? 'FFDC2626' : Kit::BLUE, empty: empty)
    end
    package.to_stream.read
  end

  private

  def summary_sheet(kit)
    total = @deliveries.size
    counts = @deliveries.map(&:status).tally
    group = ->(statuses) { counts.values_at(*statuses).compact.sum }
    rows = STATUS_SHEETS.map { |name, _title, statuses, _empty| [name == 'Needs Attention' ? 'Needs attention' : name, group.call(statuses)] }
                        .map { |label, count| [label, count, total.zero? ? 0 : count.fdiv(total)] }
    rows << ['Total', total, total.zero? ? 0 : 1]
    kit.table(kit.claim_name('Summary'), title: "#{@event.title}: email delivery report",
                                         subtitle: "How many emails are in each state, as of #{@now.strftime('%d %b %Y, %H:%M')}. Fix addresses in the panel (Email Status).",
                                         columns: SUMMARY_COLUMNS, rows: rows, tab: Kit::NAVY)
  end

  def list_sheet(kit, name, title, deliveries, tab:, empty: 'No emails yet.')
    kit.table(kit.claim_name(name), title: "#{@event.title}: #{title.downcase}",
                                    subtitle: "#{deliveries.size} email#{'s' unless deliveries.size == 1}. As of #{@now.strftime('%d %b %Y, %H:%M')}.",
                                    columns: COLUMNS, rows: deliveries.map { |delivery| row_for(delivery) },
                                    tab: tab, empty: empty)
  end

  def row_for(delivery)
    label, tone = OUTCOMES.fetch(delivery.status, [delivery.status.humanize, nil])
    ticket = delivery.related if delivery.related_type == 'Ticket'
    [ticket&.attendee_name.to_s, delivery.recipient.to_s, ticket&.attendee_phone.to_s,
     EMAIL_TYPES.fetch(delivery.mailer_action) { delivery.mailer_action.humanize },
     [label, tone], reason_for(delivery), what_to_do(delivery.status), delivery.created_at, delivery.delivered_at]
  end

  def reason_for(delivery)
    return "This email address can't receive mail" if delivery.failure_reason == 'invalid_recipient'

    REASONS.fetch(delivery.status, '')
  end

  def what_to_do(status)
    return '' unless EmailDelivery::PROBLEM_STATUSES.include?(status)
    return 'Resend the email' if status == 'failed'

    'Correct the email address, then resend'
  end
end
