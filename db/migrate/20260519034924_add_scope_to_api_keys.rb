class AddScopeToApiKeys < ActiveRecord::Migration[8.0]
  def up
    add_column :api_keys, :scope, :string, default: 'read_only', null: false
    add_index :api_keys, :scope

    # Existing keys were created before scope existed and had unrestricted
    # CRUD; preserve that behavior so we don't silently break callers like the
    # OGSE integration. New keys default to read_only.
    execute <<~SQL.squish
      UPDATE api_keys
      SET scope = 'read_write'
      WHERE created_at < '#{Time.current.iso8601}'
    SQL
  end

  def down
    remove_index :api_keys, :scope
    remove_column :api_keys, :scope
  end
end
