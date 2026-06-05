require 'rails_helper'

RSpec.describe 'Resend webhooks', type: :request do
  let!(:delivery) { create(:email_delivery, :sent, provider_message_id: 'email_123') }
  let(:payload) do
    {
      type: 'email.delivered',
      data: {
        email_id: 'email_123',
        to: ['attendee@example.com']
      }
    }.to_json
  end

  before do
    allow(Resend::Webhooks).to receive(:verify).and_return(true)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('RESEND_WEBHOOK_SECRET', '').and_return('whsec_test')
  end

  it 'updates a delivery to delivered' do
    post '/v1/public/resend/webhook',
         params: payload,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'svix-id' => 'msg_123',
           'svix-timestamp' => Time.current.to_i.to_s,
           'svix-signature' => 'v1,test'
         }

    expect(response).to have_http_status(:ok)
    expect(delivery.reload.status).to eq('delivered')
    expect(delivery.delivered_at).to be_present
  end

  it 'rejects invalid signatures' do
    allow(Resend::Webhooks).to receive(:verify).and_raise(StandardError, 'No matching signature found')

    post '/v1/public/resend/webhook',
         params: payload,
         headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
