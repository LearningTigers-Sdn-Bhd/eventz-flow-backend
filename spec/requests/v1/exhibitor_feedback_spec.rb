require 'rails_helper'

RSpec.describe 'Exhibitor feedback', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) do
    record = create(:event, status: :published, start_date: 1.day.ago, end_date: 3.hours.ago)
    create(:event_assignment, role: :event_admin, event: record, user: organizer)
    record
  end
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }
  let(:base) { "/v1/events/#{event.id}/feedback_form" }

  def build_exhibitor(company, email: "#{company.downcase.tr(' ', '')}@example.com", kits: 1)
    exhibitor = create(:exhibitor, event: event)
    kits.times do
      create(:exhibitor_kit, event_vendor: exhibitor, company_name: company, pic_email_address: email,
                             payment_status: :paid, booking_status: :active)
    end
    exhibitor
  end

  def json = JSON.parse(response.body)

  describe 'organizer form per audience' do
    it 'keeps a separate form for exhibitors alongside the ticket form' do
      post base, params: { feedback_form: { title: 'Visitors' } }, headers: headers
      expect(response).to have_http_status(:created)
      post base, params: { audience: 'exhibitor', feedback_form: { title: 'Exhibitors' } }, headers: headers
      expect(response).to have_http_status(:created)
      expect(json['data']['audience']).to eq('exhibitor')

      expect(event.reload.feedback_form.title).to eq('Visitors')
      expect(event.exhibitor_feedback_form.title).to eq('Exhibitors')

      get base, params: { audience: 'exhibitor' }, headers: headers
      expect(json['data']['title']).to eq('Exhibitors')
      get base, headers: headers
      expect(json['data']['title']).to eq('Visitors')
    end
  end

  describe 'public form and submission' do
    let!(:form) { FeedbackForm.create!(event:, title: 'Exhibitors', audience: :exhibitor) }
    let!(:question) { form.feedback_questions.create!(question_text: 'Rate', question_type: :rating, position: 0, routing_rules: []) }
    let!(:exhibitor) { build_exhibitor('Acme', kits: 3) }
    let(:token) { exhibitor.signed_id(purpose: :feedback) }
    let(:public_base) { "/v1/public/events/#{event.slug}/feedback_form" }

    def submit(token_value, answers: [{ question_id: question.id, answer_text: '5' }])
      post '/v1/public/feedback_responses',
           params: { form_id: form.id, exhibitor_token: token_value, answers: answers }, as: :json
    end

    it 'opens the exhibitor form for an exhibitor link and not the ticket form' do
      get public_base, params: { exhibitor: token }
      expect(response).to have_http_status(:ok)
      expect(json['data']['audience']).to eq('exhibitor')
      expect(json['data']['company_name']).to eq('Acme')
      expect(json['data']['already_submitted']).to be(false)
    end

    it 'records one response per company and blocks a second' do
      submit(token)
      expect(response).to have_http_status(:created)
      expect(form.feedback_responses.pluck(:exhibitor_id)).to eq([exhibitor.id])

      submit(token)
      expect(response).to have_http_status(:unprocessable_content)

      get public_base, params: { exhibitor: token }
      expect(json['data']['already_submitted']).to be(true)
    end

    it 'rejects a tampered token, another event, and a bare link' do
      submit('nope')
      expect(response).to have_http_status(:unprocessable_content)

      other_event_exhibitor = create(:exhibitor, event: create(:event))
      submit(other_event_exhibitor.signed_id(purpose: :feedback))
      expect(response).to have_http_status(:unprocessable_content)

      get public_base, params: { exhibitor: 'nope' }
      expect(response).to have_http_status(:not_found)
    end

    it 'shows the company in the organizer responses and counts it in the response rate' do
      submit(token)
      build_exhibitor('Other Co')

      get "#{base}/responses", params: { audience: 'exhibitor' }, headers: headers
      row = json['data'].first
      expect(row['ticket']['attendee_name']).to eq('Acme')
      expect(row['ticket']['ticket_type_name']).to eq('Exhibitor')

      get "#{base}/responses", params: { audience: 'exhibitor', q: 'acme' }, headers: headers
      expect(json['data'].size).to eq(1)

      get "#{base}/summary", params: { audience: 'exhibitor' }, headers: headers
      expect(json['data']['response_rate']).to include('eligible' => 2, 'responded' => 1)
    end

    describe 'non-responders and reminders' do
      before do
        event.create_event_email_setting!(thank_you_include_feedback: true)
        build_exhibitor('Other Co')
        submit(token)
      end

      it 'lists companies that have not answered and reminds them once' do
        get "#{base}/non_responders", params: { audience: 'exhibitor' }, headers: headers
        expect(json['data'].map { |r| r['attendee_name'] }).to eq(['Other Co'])

        expect do
          post "#{base}/remind", params: { audience: 'exhibitor', all: true }, headers: headers
        end.to have_enqueued_job(EmailDeliveryJob).once
        expect(json['data']).to include('queued' => 1)

        post "#{base}/remind", params: { audience: 'exhibitor', all: true }, headers: headers
        expect(json['data']).to include('queued' => 0)
      end
    end
  end
end

RSpec.describe SendThankYouEmailsJob, 'for exhibitors' do
  let(:event) { create(:event, status: :published, start_date: 1.day.ago, end_date: 3.hours.ago) }

  before do
    # Visitors are off so only the exhibitor mail can show up.
    event.create_event_email_setting!(thank_you_exhibitors: true, disabled_categories: ['thank_you'])
    big = create(:exhibitor, event:)
    2.times { create(:exhibitor_kit, event_vendor: big, company_name: 'Big Co', pic_email_address: 'big@example.com', payment_status: :paid) }
    create(:exhibitor_kit, event_vendor: create(:exhibitor, event:), company_name: 'Unpaid', pic_email_address: 'u@example.com', payment_status: :unpaid)
    create(:ticket, :checked_in, :paid, event:, attendee_email: 'visitor@example.com')
  end

  it 'sends one email per paid company, once' do
    expect { described_class.new.perform }.to have_enqueued_job(EmailDeliveryJob).once
    expect(event.reload.exhibitor_thank_you_sent_at).to be_present
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'sends nothing when the exhibitor toggle is off' do
    event.event_email_setting.update!(thank_you_exhibitors: false)
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'respects the exhibitor_thank_you category toggle' do
    event.event_email_setting.update!(disabled_categories: %w[thank_you exhibitor_thank_you])
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end
end

RSpec.describe ThankYouMailer, 'exhibitor emails' do
  let(:event) { create(:event) }
  let(:exhibitor) { create(:exhibitor, event:) }

  before do
    create(:exhibitor_kit, event_vendor: exhibitor, company_name: 'Acme', pic_email_address: 'pic@example.com', payment_status: :paid)
  end

  it 'greets the company and links to the exhibitor form only when one is ready' do
    mail = described_class.exhibitor_thank_you_email(exhibitor)
    expect(mail.to).to eq(['pic@example.com'])
    expect(mail.html_part.body.to_s).to include('Acme')
    expect(mail.html_part.body.to_s).not_to include('Share Your Feedback')

    event.create_event_email_setting!(thank_you_include_feedback: true)
    form = FeedbackForm.create!(event:, title: 'Exhibitors', audience: :exhibitor)
    form.feedback_questions.create!(question_text: 'How was it?', question_type: :text, position: 0, routing_rules: [])
    body = described_class.exhibitor_thank_you_email(exhibitor.reload).html_part.body.to_s
    expect(body).to include('Share Your Feedback', 'feedback?exhibitor=')
  end
end

RSpec.describe 'Exhibitor feedback links', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) do
    record = create(:event)
    create(:event_assignment, role: :event_admin, event: record, user: organizer)
    record
  end
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }

  it 'searches companies and returns a working personal link' do
    exhibitor = create(:exhibitor, event:)
    create(:exhibitor_kit, event_vendor: exhibitor, company_name: 'Acme Corp', pic_email_address: 'a@example.com', payment_status: :paid)
    create(:exhibitor_kit, event_vendor: create(:exhibitor, event:), company_name: 'Zed', pic_email_address: 'z@example.com', payment_status: :paid)

    get "/v1/events/#{event.id}/feedback_form/exhibitor_links", params: { audience: 'exhibitor', q: 'acme' }, headers: headers
    rows = JSON.parse(response.body)['data']
    expect(rows.map { |r| r['company_name'] }).to eq(['Acme Corp'])
    get "/v1/public/feedback_links/#{rows.first['url'].split('/').last}"
    token = JSON.parse(response.body)['data']['exhibitor_token']
    expect(Exhibitor.find_signed(token, purpose: :feedback)).to eq(exhibitor)
  end

  it 'issues a reusable short link that resolves to the exhibitor form' do
    exhibitor = create(:exhibitor, event:)
    create(:exhibitor_kit, event_vendor: exhibitor, company_name: 'Acme', pic_email_address: 'a@example.com', payment_status: :paid)

    post "/v1/events/#{event.id}/feedback_form/exhibitor_link", params: { audience: 'exhibitor', exhibitor_id: exhibitor.id }, headers: headers
    url = JSON.parse(response.body)['data']['url']
    expect(url).to match(%r{/feedback/\w{8}\z})
    post "/v1/events/#{event.id}/feedback_form/exhibitor_link", params: { exhibitor_id: exhibitor.id }, headers: headers
    expect(JSON.parse(response.body)['data']['url']).to eq(url)

    get "/v1/public/feedback_links/#{url.split('/').last}"
    data = JSON.parse(response.body)['data']
    expect(data['event_slug']).to eq(event.slug)
    expect(Exhibitor.find_signed(data['exhibitor_token'], purpose: :feedback)).to eq(exhibitor)

    get '/v1/public/feedback_links/nope1234'
    expect(response).to have_http_status(:not_found)

    other = create(:exhibitor, event: create(:event))
    post "/v1/events/#{event.id}/feedback_form/exhibitor_link", params: { exhibitor_id: other.id }, headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
