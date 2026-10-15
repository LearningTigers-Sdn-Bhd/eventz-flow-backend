require 'rails_helper'

# Focused check for VoucherRedemptionsController#capture_lead_for:
# a successful voucher redemption for a ticket/visitor should also
# capture an EventLead for the redeeming vendor, so exhibitors don't
# need to scan the same attendee twice.
RSpec.describe 'V1::VoucherRedemptions lead capture', type: :request do
  let(:event) { create(:event) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:ticket) { create(:ticket, event: event) }

  before do
    allow_any_instance_of(User).to receive(:is_org_owner?).and_return(false)
    allow_any_instance_of(User).to receive(:is_organizer?).and_return(false)
    allow(vendor_user).to receive(:is_vendor?).and_return(true)
  end

  def auth_header(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  it 'captures an EventLead when the vendor has an event_vendor record for this event' do
    create(:exhibitor, event: event, vendor: vendor_user)
    voucher = create(:voucher, vendor: vendor_user, event: event, voucher_type: :fixed_amount, voucher_value: 10)

    expect do
      post '/v1/voucher_redemptions',
           params: { voucher_redemption: { voucher_uuid: voucher.voucher_uuid, net_amount: 90, ticket_id: ticket.public_id } },
           headers: auth_header(vendor_user)
    end.to change(EventLead, :count).by(1)

    expect(response).to have_http_status(:created)
    lead = EventLead.last
    expect(lead.leadable).to eq(ticket)
    expect(lead.event_vendor.vendor_id).to eq(vendor_user.id)
  end

  it 'does not fail redemption when the vendor has no event_vendor record for this event' do
    voucher = create(:voucher, vendor: vendor_user, event: event, voucher_type: :fixed_amount, voucher_value: 10)

    expect do
      post '/v1/voucher_redemptions',
           params: { voucher_redemption: { voucher_uuid: voucher.voucher_uuid, net_amount: 90, ticket_id: ticket.public_id } },
           headers: auth_header(vendor_user)
    end.not_to change(EventLead, :count)

    expect(response).to have_http_status(:created)
  end

  it 'does not duplicate a lead already captured for the same ticket' do
    exhibitor_vendor = create(:exhibitor, event: event, vendor: vendor_user)
    create(:event_lead, event_vendor: exhibitor_vendor, leadable: ticket)
    voucher = create(:voucher, vendor: vendor_user, event: event, voucher_type: :fixed_amount, voucher_value: 10)

    expect do
      post '/v1/voucher_redemptions',
           params: { voucher_redemption: { voucher_uuid: voucher.voucher_uuid, net_amount: 90, ticket_id: ticket.public_id } },
           headers: auth_header(vendor_user)
    end.not_to change(EventLead, :count)

    expect(response).to have_http_status(:created)
  end
end
