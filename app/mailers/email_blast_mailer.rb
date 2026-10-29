class EmailBlastMailer < ApplicationMailer
  # preview: skip downloading attachments when only rendering the HTML for the composer.
  def blast_email(blast, to_email, preview: false)
    @blast = blast
    @event = blast.event
    setting = @event.event_email_setting
    @sender_name = setting&.sender_name.presence || @event.title
    @contact_email = setting&.contact_email.presence
    (preview ? [] : blast.attachments).each { |file| attachments[file.filename.to_s] = { mime_type: file.content_type, content: file.download } }

    headers = {
      to: to_email,
      from: format_sender(@sender_name, setting&.sender_address.presence || DEFAULT_SENDER_ADDRESS),
      subject: blast.subject
    }
    return html_email(headers) if blast.html?

    attachments.inline['banner'] = { mime_type: blast.banner.content_type, content: blast.banner.download } if blast.banner.attached?
    mail(headers)
  end

  private

  # The organizer's HTML is the whole email: no EventzFlow layout around it.
  def html_email(headers)
    text = Loofah.html5_fragment(@blast.body).text(encode_special_chars: false).squeeze("\n").strip
    mail(headers) do |format|
      format.text { render plain: text }
      format.html { render html: @blast.body.html_safe, layout: false }
    end
  end
end
