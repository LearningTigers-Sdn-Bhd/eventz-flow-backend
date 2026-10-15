# frozen_string_literal: true

class AddUseFeedbackToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_feedback, :boolean, default: false, null: false
  end
end
