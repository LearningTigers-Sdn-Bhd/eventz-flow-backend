require 'rails_helper'

RSpec.describe 'V1::EmailBlasts', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:owner_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:organizer_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }
  let!(:event) { create(:event) }
  let(:base) { "/v1/events/#{event.id}/email_blasts" }

  def json = JSON.parse(response.body)

  it 'forbids organizers' do
    get base, headers: organizer_headers
    expect(response).to have_http_status(:forbidden)
    post base, params: { subject: 'Hi', body: '<p>x</p>' }, headers: organizer_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'creates a draft and strips unsafe html' do
    post base, params: { subject: 'Hi', body: '<p onclick="x()">Hello</p><script>alert(1)</script><img src=x>' }, headers: owner_headers
    expect(response).to have_http_status(:created)
    expect(json['data']['status']).to eq('draft')
    expect(json['data']['body']).to eq('<p>Hello</p>alert(1)')
  end

  describe 'delivering' do
    let!(:blast) { create_blast }

    def create_blast
      post base, params: { subject: 'Summit', body: '<p>Hello</p>' }, headers: owner_headers
      EmailBlast.last
    end

    before do
      create(:ticket, event: event, attendee_email: 'A@example.com')
      create(:ticket, event: event, attendee_email: 'a@example.com') # same address, one copy
      create(:ticket, event: event, attendee_email: 'b@example.com')
      create(:ticket, event: event, attendee_email: nil)
      create(:ticket, event: event, attendee_email: 'waitlist@example.com', waiting_list: true)
    end

    it 'counts one recipient per address, excluding waitlist' do
      get "#{base}/audience", headers: owner_headers
      expect(json['recipient_count']).to eq(2)
    end

    it 'queues one delivery per recipient and refuses a second send' do
      expect { post "#{base}/#{blast.id}/deliver", headers: owner_headers }
        .to have_enqueued_job(SendEmailBlastJob).with(blast.id)
      expect(response).to have_http_status(:accepted)

      expect { SendEmailBlastJob.perform_now(blast.id) }.to change(EmailDelivery, :count).by(2)
      expect(EmailDelivery.where(related: blast).pluck(:recipient)).to contain_exactly('A@example.com', 'b@example.com')

      post "#{base}/#{blast.id}/deliver", headers: owner_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'uses the default sender, then the event sender once configured, with no reply-to' do
      mail = EmailBlastMailer.blast_email(blast, 'x@example.com')
      expect(mail.from).to eq([ApplicationMailer::DEFAULT_SENDER_ADDRESS])
      expect(mail.reply_to).to be_blank

      EventEmailSetting.create!(event: event, sender_name: 'SCCC', sender_address: 'sccc@notify.eventzflow.com')
      mail = EmailBlastMailer.blast_email(blast.reload, 'x@example.com')
      expect(mail.from).to eq(['sccc@notify.eventzflow.com'])
      expect(mail[:from].to_s).to include('SCCC')
    end

    it 'returns the rendered preview' do
      get "#{base}/#{blast.id}/preview", headers: owner_headers
      expect(response).to have_http_status(:ok)
      expect(json['html']).to include('Hello')
    end
  end

  it 'inlines the banner in the email and the preview' do
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
    blast = event.email_blasts.create!(subject: 'Banner', body: '<p>x</p>')
    blast.banner.attach(io: StringIO.new(png), filename: 'b.png', content_type: 'image/png')

    mail = EmailBlastMailer.blast_email(blast, 'x@example.com')
    expect(mail.attachments['banner']).to be_inline

    get "#{base}/#{blast.id}/preview", headers: owner_headers
    expect(json['html']).to include('data:image/png;base64,')
    expect(json['html']).not_to include('cid:')
  end

  it 'saves a template, lists it apart, and starts a draft from it' do
    post base, params: { subject: 'Reusable', body: '<p>Hi</p>' }, headers: owner_headers
    blast_id = json['data']['id']

    post "#{base}/#{blast_id}/duplicate", params: { template_name: 'Speakers' }, headers: owner_headers
    expect(json['data']).to include('status' => 'template', 'name' => 'Speakers', 'subject' => 'Reusable')
    template_id = json['data']['id']

    get base, params: { status: 'template' }, headers: owner_headers
    expect(json['data'].pluck('id')).to eq([template_id])

    post "#{base}/#{template_id}/duplicate", headers: owner_headers
    expect(json['data']).to include('status' => 'draft', 'name' => nil, 'body' => '<p>Hi</p>')

    delete "#{base}/#{template_id}", headers: owner_headers
    expect(response).to have_http_status(:no_content)
  end

  it 'treats a blank template name as a plain draft' do
    post base, params: { subject: 'Reusable', body: 'x' }, headers: owner_headers
    post "#{base}/#{json['data']['id']}/duplicate", params: { template_name: ' ' }, headers: owner_headers
    expect(json['data']['status']).to eq('draft')
  end

  it 'shows sender and per-recipient results' do
    get "#{base}/audience", headers: owner_headers
    expect(json).to include('sender_address' => ApplicationMailer::DEFAULT_SENDER_ADDRESS, 'sender_name' => event.title)

    create(:ticket, event: event, attendee_email: 'a@example.com')
    post base, params: { subject: 'Hi', body: 'x' }, headers: owner_headers
    blast = EmailBlast.last
    post "#{base}/#{blast.id}/deliver", headers: owner_headers
    SendEmailBlastJob.perform_now(blast.id)
    get "#{base}/#{blast.id}", headers: owner_headers
    expect(json['data']['recipients'].pluck('email')).to eq(['a@example.com'])
  end

  describe 'custom HTML' do
    let(:html) do
      '<html><head><style>.x{}</style><script>alert(1)</script></head><body onload="x()">' \
        '<table style="background:#fff"><tr><td><a href="javascript:x()">bad</a><a href="https://ok.com">ok</a>' \
        '<img src="https://ok.com/i.png"></td></tr></table></body></html>'
    end

    it 'sends the organizer HTML as the whole email, minus scripts and unsafe attributes' do
      post base, params: { subject: 'Designed', body: html, body_format: 'html' }, headers: owner_headers
      expect(json['data']).to include('body_format' => 'html')
      saved = json['data']['body']
      expect(saved).to include('<table', 'https://ok.com', 'background:#fff')
      expect(saved).not_to match(/script|onload|javascript:|<style/i)

      mail = EmailBlastMailer.blast_email(EmailBlast.last, 'x@example.com')
      expect(mail.html_part.body.decoded).to include('<table')
      expect(mail.html_part.body.decoded).not_to include('EventzFlow')
      expect(mail.text_part.body.decoded).to include('ok')
    end

    it 'rejects an unknown format' do
      post base, params: { subject: 'Hi', body: 'x', body_format: 'markdown' }, headers: owner_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'style and live preview' do
    it 'shows the style label with the event name underneath, and the plain look for general' do
      post base, params: { subject: 'Hi', body: 'x', style_key: 'important' }, headers: owner_headers
      expect(json['data']['style_key']).to eq('important')
      html = EmailBlastMailer.blast_email(EmailBlast.last, 'x@example.com').html_part.body.decoded
      expect(html).to include('Important update').and include(event.title)

      general = event.email_blasts.create!(subject: 'Hi', body: 'x')
      expect(EmailBlastMailer.blast_email(general, 'x@example.com').html_part.body.decoded).not_to include('Important update')
    end

    it 'rejects an unknown style' do
      post base, params: { subject: 'Hi', body: 'x', style_key: 'neon' }, headers: owner_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders unsaved edits without saving, and cleans the body like a real send' do
      expect do
        post "#{base}/preview_draft", params: { subject: 'Draft', body: '<p onclick="x()">Hello</p><script>1</script>', body_format: 'rich', style_key: 'reminder' }, headers: owner_headers
      end.not_to change(EmailBlast, :count)
      expect(response).to have_http_status(:ok)
      expect(json['html']).to include('Hello', 'Reminder')
      expect(json['html']).not_to match(/onclick|<script/)
    end

    it 'previews with a blank subject and forbids organizers' do
      post "#{base}/preview_draft", params: { body: 'x' }, headers: owner_headers
      expect(json['html']).to include('(no subject)')
      post "#{base}/preview_draft", params: { body: 'x' }, headers: organizer_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'attachments' do
    def pdf(name = 'agenda.pdf', size = 100) = Rack::Test::UploadedFile.new(StringIO.new('%PDF-1.4 ' + ('a' * size)), 'application/pdf', original_filename: name)

    it 'attaches files, delivers them with the email, and can remove them' do
      post base, params: { subject: 'Hi', body: 'x', attachments: [pdf, pdf('map.pdf')] }, headers: owner_headers
      expect(response).to have_http_status(:created)
      expect(json['data']['attachments'].pluck('filename')).to contain_exactly('agenda.pdf', 'map.pdf')

      blast = EmailBlast.last
      mail = EmailBlastMailer.blast_email(blast, 'x@example.com')
      expect(mail.attachments.reject(&:inline?).map(&:filename)).to contain_exactly('agenda.pdf', 'map.pdf')

      remove_id = json['data']['attachments'].first['id']
      patch "#{base}/#{blast.id}", params: { remove_attachment_ids: [remove_id] }, headers: owner_headers
      expect(json['data']['attachments'].size).to eq(1)

      copy = blast.reload.duplicate(created_by: org_owner)
      copy.save!
      expect(copy.attachments.map { |a| a.filename.to_s }).to eq(blast.attachments.map { |a| a.filename.to_s })
    end

    it 'refuses unsupported types and oversized totals' do
      exe = Rack::Test::UploadedFile.new(StringIO.new('MZ'), 'application/x-msdownload', original_filename: 'a.exe')
      post base, params: { subject: 'Hi', body: 'x', attachments: [exe] }, headers: owner_headers
      expect(response).to have_http_status(:unprocessable_content)

      big = pdf('big.pdf', 6.megabytes)
      post base, params: { subject: 'Hi', body: 'x', attachments: [big] }, headers: owner_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json['errors'].join).to include('5 MB')
    end
  end

  it 'rejects sending with no recipients' do
    post base, params: { subject: 'Hi', body: 'x' }, headers: owner_headers
    post "#{base}/#{EmailBlast.last.id}/deliver", headers: owner_headers
    expect(response).to have_http_status(:unprocessable_content)
  end
end
