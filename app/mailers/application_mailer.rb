class ApplicationMailer < ActionMailer::Base
  DEFAULT_PAYMENT_RECEIPT_EMAIL = 'eventpayment@eventzflow.com'.freeze

  # Bare address, shared by every mailer. Must be on a domain verified with the
  # mail provider; set MAIL_FROM to move sending to another domain.
  DEFAULT_SENDER_ADDRESS = (ENV['MAIL_FROM'].presence || 'notifications@updates.eventzflow.com').freeze

  default from: "EventzFlow <#{DEFAULT_SENDER_ADDRESS}>"
  helper EmailHelper
  layout 'email'

  private

  def payment_receipt_bcc(additional: nil)
    recipients = [
      DEFAULT_PAYMENT_RECEIPT_EMAIL,
      *Array(additional)
    ]

    recipients
      .map { |email| email.to_s.strip }
      .reject(&:blank?)
      .uniq
  end

  # Builds a "Name <addr>" From header via Mail::Address so display names
  # with commas/special chars (e.g. event titles like "Foo, Bar & Baz") get
  # properly quoted instead of being misparsed as multiple addresses, which
  # made Resend blow up with `undefined method 'formatted' for an instance
  # of Mail::UnstructuredField`.
  def format_sender(name, address)
    Mail::Address.new(address).tap { |a| a.display_name = name }.format
  end
end
