require 'rails_helper'

RSpec.describe RegistrationForm, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should have_many(:registration_form_ticket_types).dependent(:destroy) }
    it { should have_many(:ticket_types).through(:registration_form_ticket_types) }
  end
end
