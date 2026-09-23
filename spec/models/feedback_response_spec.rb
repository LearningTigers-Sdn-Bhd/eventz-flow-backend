require 'rails_helper'

RSpec.describe FeedbackResponse, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:feedback_form) }
    it { is_expected.to belong_to(:ticket).optional }
    it { is_expected.to have_many(:feedback_answers).dependent(:destroy) }
  end

  it 'requires a submission timestamp' do
    response = FeedbackResponse.new(feedback_form: FeedbackForm.new(title: 'Form'))

    expect(response).not_to be_valid
    expect(response.errors[:submitted_at]).to be_present
  end
end
