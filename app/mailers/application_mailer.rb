class ApplicationMailer < ActionMailer::Base
  DEFAULT_PAYMENT_RECEIPT_EMAIL = 'eventpayment@eventzflow.com'.freeze

  default from: 'EventzFlow <notifications@updates.eventzflow.com>'
  layout 'mailer'

  private

  def payment_receipt_bcc(additional: nil)
    recipients = [
      DEFAULT_PAYMENT_RECEIPT_EMAIL,
      *csv_emails(ENV['PAYMENT_RECEIPT_EMAILS']),
      *Array(additional)
    ]

    recipients
      .map { |email| email.to_s.strip }
      .reject(&:blank?)
      .uniq
  end

  def csv_emails(raw)
    raw.to_s.split(',')
  end
end
