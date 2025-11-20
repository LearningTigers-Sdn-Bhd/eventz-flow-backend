class MakeVoucherRedemptionPolymorphic < ActiveRecord::Migration[8.0]
  def change
    # 1. Rename the usage table to be generic
    rename_table :user_voucher_usages, :voucher_usages

    # 2. Update voucher_usages to be polymorphic (using integer for type)
    change_table :voucher_usages do |t|
      t.bigint :redeemer_id
      t.integer :redeemer_type, limit: 2  # smallint for enum
      t.index [:redeemer_type, :redeemer_id]
    end

    # 3. Update voucher_redemption_logs to be polymorphic (using integer for type)
    change_table :voucher_redemption_logs do |t|
      t.bigint :redeemer_id
      t.integer :redeemer_type, limit: 2  # smallint for enum
      t.index [:redeemer_type, :redeemer_id]
    end

    # 4. Data Migration (Safe up/down)
    reversible do |dir|
      dir.up do
        # Migrate existing User data to the polymorphic columns
        # Using integer 0 for User type (define enum in models)
        execute <<~SQL
          UPDATE voucher_usages SET redeemer_id = user_id, redeemer_type = 0;
          UPDATE voucher_redemption_logs SET redeemer_id = user_id, redeemer_type = 0;
        SQL

        # Now it is safe to remove the old user_id column
        # We must remove the foreign key constraint first if it exists
        remove_column :voucher_usages, :user_id
        remove_column :voucher_redemption_logs, :user_id
      end

      dir.down do
        # Add user_id back
        add_reference :voucher_usages, :user, foreign_key: true
        add_reference :voucher_redemption_logs, :user, foreign_key: true

        # Restore data (Only works if all redeemers are Users!)
        # Handle both varchar 'User' (old) and integer 0 (new) for compatibility
        execute <<~SQL
          UPDATE voucher_usages SET user_id = redeemer_id 
          WHERE redeemer_type::text IN ('0', 'User');
          
          UPDATE voucher_redemption_logs SET user_id = redeemer_id 
          WHERE redeemer_type::text IN ('0', 'User');
        SQL
      end
    end
  end
end
