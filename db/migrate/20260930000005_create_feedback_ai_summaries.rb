# frozen_string_literal: true

class CreateFeedbackAiSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_ai_summaries do |t|
      t.references :feedback_form, null: false, foreign_key: true
      t.references :ai_model, foreign_key: { on_delete: :nullify }
      t.references :generated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :status, null: false, default: 'queued'
      t.string :model_name_used
      t.jsonb :filters, null: false, default: {}
      t.jsonb :content
      t.text :error
      t.integer :responses_count, null: false, default: 0
      t.integer :comments_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :feedback_ai_summaries, %i[feedback_form_id created_at]
  end
end
