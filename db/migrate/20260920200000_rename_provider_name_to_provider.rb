class RenameProviderNameToProvider < ActiveRecord::Migration[8.0]
  def change
    rename_index :ai_integrations,
                 'index_ai_integrations_on_user_id_and_provider_name',
                 'index_ai_integrations_on_user_id_and_provider'
    rename_column :ai_integrations, :provider_name, :provider
  end
end
