require 'rails_helper'

# MillionSend rejects the gem's default byte-array attachment content
# ("expected string, received array"); Base64 strings work on both providers.
RSpec.describe 'Resend attachment encoding' do
  let(:bytes) { "%PDF-1.4\x00\xFF\xFE binary".b }

  def build_params(mail)
    Resend::Mailer.new({}).build_resend_params(mail)
  end

  it 'sends attachment content as a Base64 string that decodes to the original bytes' do
    mail = Mail.new(from: 'a@example.com', to: 'b@example.com', subject: 'Ticket')
    mail.body = 'hello'
    mail.attachments['ticket.pdf'] = { mime_type: 'application/pdf', content: bytes }

    attachment = build_params(mail)[:attachments].first

    expect(attachment[:filename]).to eq('ticket.pdf')
    expect(attachment[:content]).to be_a(String)
    expect(Base64.strict_decode64(attachment[:content])).to eq(bytes)
  end

  it 'keeps the content id for inline attachments' do
    mail = Mail.new(from: 'a@example.com', to: 'b@example.com', subject: 'Logo')
    mail.body = 'hello'
    mail.attachments.inline['logo.png'] = { mime_type: 'image/png', content: bytes }

    attachment = build_params(mail)[:attachments].first

    expect(attachment[:content_id]).to be_present
    expect(attachment[:content]).to be_a(String)
  end
end
