require 'rails_helper'

RSpec.describe 'V1::Events membership uniqueness', type: :request do
  let(:admin) { create(:user, :org_owner) }
  let(:event) { create(:event) }

  def toggle(enabled)
    patch "/v1/events/#{event.id}",
          params: { event: { require_unique_membership_numbers: enabled } },
          headers: auth_headers(admin), as: :json
  end

  it 'persists and returns both toggle values' do
    [false, true].each do |enabled|
      toggle(enabled)
      expect(response).to have_http_status(:ok)
      expect(json_response['require_unique_membership_numbers']).to eq(enabled)
      expect(event.reload.require_unique_membership_numbers).to eq(enabled)
    end
  end

  it 'returns a readable 422 and keeps the setting off when duplicates exist' do
    event.update!(require_unique_membership_numbers: false)
    ticket_type = create(:ticket_type, event: event)
    2.times do
      create(:ticket, event: event, ticket_type: ticket_type,
                      custom_fields_data: { 'membership_no' => 'MEM001' })
    end
    toggle(true)
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['errors'].join).to include('duplicate membership')
    expect(event.reload.require_unique_membership_numbers).to be(false)
  end
end
