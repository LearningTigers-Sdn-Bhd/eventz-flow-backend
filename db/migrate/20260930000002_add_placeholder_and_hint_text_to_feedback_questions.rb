# frozen_string_literal: true

class AddPlaceholderAndHintTextToFeedbackQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_questions, :placeholder, :string
    add_column :feedback_questions, :hint_text, :string
  end
end
