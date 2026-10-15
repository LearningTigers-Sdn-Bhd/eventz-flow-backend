Resend.api_key = ENV.fetch("RESEND_API_KEY", "")

# The resend gem sends attachment content as an array of bytes. Resend accepts
# that, but MillionSend rejects it ("attachments.N.content: expected string,
# received array"). A Base64 string is valid for both providers.
module Base64ResendAttachments
  def get_attachments(mail)
    mail.attachments.map do |part|
      attachment = { filename: part.filename, content: Base64.strict_encode64(part.body.decoded) }
      # Rails uses the auto generated cid for inline attachments
      attachment[:content_id] = part.cid if part.inline?
      attachment
    end
  end
end

Resend::Mailer.prepend(Base64ResendAttachments)
