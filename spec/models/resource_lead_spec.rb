# spec/models/resource_lead_spec.rb
require 'rails_helper'

RSpec.describe ResourceLead, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
  end
end
