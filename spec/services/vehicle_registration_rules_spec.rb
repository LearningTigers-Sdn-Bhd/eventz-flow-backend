require 'rails_helper'

RSpec.describe VehicleRegistrationRules do
  it 'allows Support - Corporate as a base ticket for competitor-support, with no included free seat' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'competitor-support')
    corporate = create(:ticket_type, event: event, name: 'Support - Corporate', status: :published, hidden: false)
    create(:registration_form_ticket_type, registration_form: form, ticket_type: corporate)

    rules = described_class.new(form)

    expect(rules.allowed_ticket_names(nil)).to include('Support - Corporate')
  end
end
