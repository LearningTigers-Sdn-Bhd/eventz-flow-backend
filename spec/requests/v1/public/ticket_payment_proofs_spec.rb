require 'rails_helper'

RSpec.describe 'V1::Public::TicketPaymentProofs', type: :request do
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) { create(:ticket_type, event: event, price: 100.00, status: :published, hidden: false) }
  let(:ticket) do
    create(:ticket, event: event, ticket_type: ticket_type, status: :pending_payment, payment_status: :pending)
  end
  let(:file) { fixture_file_upload('test_image.png', 'image/jpeg') }

  def proof_path(t = ticket)
    "/v1/public/events/#{event.slug}/tickets/#{t.public_id}/payment_proof"
  end

  describe 'POST payment_proof' do
    it 'attaches the proof and stamps bank_transfer' do
      post proof_path, params: { payment_proof: file }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data['payment_proof_uploaded']).to be true
      expect(data['payment_proof_url']).to be_present
      expect(data['payment_status']).to eq('pending')

      payment = ticket.reload.ticket_payment
      expect(payment.payment_proof).to be_attached
      expect(payment.payment_method).to eq('bank_transfer')
      expect(payment.payment_screenshot_url).to be_present
    end

    it 'replaces an existing proof' do
      post proof_path, params: { payment_proof: file }
      post proof_path, params: { payment_proof: fixture_file_upload('test_image.png', 'image/png') }

      expect(response).to have_http_status(:ok)
      expect(ticket.reload.ticket_payment.payment_proof).to be_attached
    end

    it 'requires a file' do
      post proof_path

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses once the ticket is paid' do
      paid_ticket = create(:ticket, event: event, ticket_type: ticket_type,
                                    status: :purchased, payment_status: :paid)

      post proof_path(paid_ticket), params: { payment_proof: file }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '404s on an unknown public_id' do
      post "/v1/public/events/#{event.slug}/tickets/#{SecureRandom.uuid}/payment_proof",
           params: { payment_proof: file }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE payment_proof' do
    it 'purges the proof and clears the screenshot url' do
      post proof_path, params: { payment_proof: file }

      delete proof_path

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data['payment_proof_uploaded']).to be false
      expect(ticket.reload.ticket_payment.payment_screenshot_url).to be_nil
    end

    it 'refuses once the ticket is paid' do
      post proof_path, params: { payment_proof: file }
      ticket.update!(payment_status: :paid, status: :purchased)

      delete proof_path

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
