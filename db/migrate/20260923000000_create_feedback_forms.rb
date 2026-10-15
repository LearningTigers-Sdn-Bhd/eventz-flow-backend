class CreateFeedbackForms < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_forms do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.string :title, null: false
      t.text :description
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    create_table :feedback_questions do |t|
      t.references :feedback_form, null: false, foreign_key: true
      t.string :question_text, null: false
      t.integer :question_type, null: false
      t.jsonb :options
      t.boolean :required, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :feedback_responses do |t|
      t.references :feedback_form, null: false, foreign_key: true
      t.references :ticket, foreign_key: true
      t.datetime :submitted_at, null: false

      t.timestamps
    end

    create_table :feedback_answers do |t|
      t.references :feedback_response, null: false, foreign_key: true
      t.references :feedback_question, null: false, foreign_key: true
      t.text :answer_text

      t.timestamps
    end
  end
end
