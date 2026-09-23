class FeedbackQuestion < ApplicationRecord
  CHOICE_TYPES = %w[single_choice multi_choice].freeze

  belongs_to :feedback_form
  has_many :feedback_answers, dependent: :restrict_with_error

  enum :question_type, {
    rating: 0,
    text: 1,
    single_choice: 2,
    multi_choice: 3,
    yes_no: 4
  }, validate: true

  validates :question_text, presence: true
  validate :validate_options

  def choice_type?
    CHOICE_TYPES.include?(question_type)
  end

  private

  def validate_options
    if choice_type?
      if options.blank?
        errors.add(:options, "can't be blank")
      elsif !options.is_a?(Array) || options.any? { |option| !option.is_a?(String) || option.blank? }
        errors.add(:options, 'must be an array of non-blank strings')
      end
    elsif !options.nil?
      errors.add(:options, 'are only allowed for choice questions')
    end
  end

end
