# frozen_string_literal: true

class AddThankYouPageToFeedbackForms < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_forms, :thank_you_title, :string
    add_column :feedback_forms, :thank_you_message, :text
  end
end
