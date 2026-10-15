class CreateAiIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider_name, null: false
      t.string :api_url, null: false
      t.text :api_key, null: false

      t.timestamps
    end

    add_index :ai_integrations, %i[user_id provider_name], unique: true

    create_table :ai_models do |t|
      t.references :ai_integration, null: false, foreign_key: true
      t.string :model_id, null: false
      t.string :display_name, null: false

      t.timestamps
    end

    add_index :ai_models, %i[ai_integration_id model_id], unique: true

    add_reference :users, :default_ai_model, index: true
    add_foreign_key :users, :ai_models, column: :default_ai_model_id, on_delete: :nullify
  end
end
