Resend.api_key = ENV.fetch("RESEND_API_KEY", "")

# MillionSend is stricter than Resend about two fields the gem builds, so we
# send the shapes that both providers accept:
# - attachments: the gem sends content as an array of bytes ("attachments.N.content:
#   expected string, received array"); a Base64 string works on both.
# - tags: UserMailer passes one tag as a bare object ("tags: expected array,
#   received object"); an array of tag objects works on both.
module ResendProviderCompat
  def get_tags(mail)
    params = super
    params[:tags] = [params[:tags]] if params[:tags].is_a?(Hash)
    params
  end

  def get_attachments(mail)
    mail.attachments.map do |part|
      attachment = { filename: part.filename, content: Base64.strict_encode64(part.body.decoded) }
      # Rails uses the auto generated cid for inline attachments
      attachment[:content_id] = part.cid if part.inline?
      attachment
    end
  end
end

Resend::Mailer.prepend(ResendProviderCompat)
