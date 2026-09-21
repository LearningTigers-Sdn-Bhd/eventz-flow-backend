# frozen_string_literal: true

class MakeAiIntegrationsSystemWide < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :users, column: :default_ai_model_id
    remove_column :users, :default_ai_model_id

    remove_index :ai_integrations, name: 'index_ai_integrations_on_user_id_and_provider'
    remove_foreign_key :ai_integrations, :users
    remove_column :ai_integrations, :user_id
    add_index :ai_integrations, :provider, unique: true

    add_column :ai_models, :is_default, :boolean, default: false, null: false
  end

  def down
    remove_column :ai_models, :is_default

    remove_index :ai_integrations, :provider
    add_column :ai_integrations, :user_id, :bigint
    add_foreign_key :ai_integrations, :users
    add_index :ai_integrations, :user_id
    add_index :ai_integrations, %i[user_id provider], unique: true, name: 'index_ai_integrations_on_user_id_and_provider'

    add_column :users, :default_ai_model_id, :bigint
    add_foreign_key :users, :ai_models, column: :default_ai_model_id, on_delete: :nullify
    add_index :users, :default_ai_model_id
  end
end
