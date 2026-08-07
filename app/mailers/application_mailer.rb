class ApplicationMailer < ActionMailer::Base
  DEFAULT_PAYMENT_RECEIPT_EMAIL = 'eventpayment@eventzflow.com'.freeze

  default from: 'EventzFlow <notifications@updates.eventzflow.com>'
  layout 'mailer'

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
