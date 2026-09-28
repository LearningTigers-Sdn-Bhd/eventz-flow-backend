# RfiDex device keys are minted with an indexed `rfd_<16 hex>` prefix so a
# lookup verifies one candidate instead of bcrypt-scanning every active key.
# Legacy keys keep a NULL prefix and keep authenticating through the old scan.
class AddRfidApiKeyPrefix < ActiveRecord::Migration[8.0]
  def change
    add_column :api_keys, :key_prefix, :string
    add_index :api_keys, :key_prefix, unique: true, where: 'key_prefix IS NOT NULL',
                                       name: 'idx_api_keys_key_prefix'
  end
end
