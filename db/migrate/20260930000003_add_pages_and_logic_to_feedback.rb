# frozen_string_literal: true

class AddPagesAndLogicToFeedback < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_forms, :display_mode, :integer, default: 0, null: false
    add_column :feedback_forms, :pages_metadata, :jsonb, default: [], null: false

    add_column :feedback_questions, :page_number, :integer, default: 1, null: false
    add_column :feedback_questions, :routing_rules, :jsonb, default: [], null: false
  end
end
