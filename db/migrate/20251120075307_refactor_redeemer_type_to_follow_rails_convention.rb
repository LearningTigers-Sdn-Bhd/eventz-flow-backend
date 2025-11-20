class RefactorRedeemerTypeToFollowRailsConvention < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add a temporary column to store the string version
    add_column :voucher_redemption_logs, :redeemer_type_temp, :string
    
    # Step 2: Migrate existing data from integer enum to string class names
    # 0 = user_redeemer -> "User"
    # 1 = visitor_redeemer -> "Visitor"
    VoucherRedemptionLog.reset_column_information
    VoucherRedemptionLog.find_each do |log|
      case log.redeemer_type
      when 0, 'user_redeemer'
        log.update_column(:redeemer_type_temp, 'User')
      when 1, 'visitor_redeemer'
        log.update_column(:redeemer_type_temp, 'Visitor')
      end
    end
    
    # Step 3: Remove the old integer column and the redundant polymorphic column
    remove_column :voucher_redemption_logs, :redeemer_type
    remove_column :voucher_redemption_logs, :polymorphic_redeemer_type
    
    # Step 4: Rename the temp column to redeemer_type
    rename_column :voucher_redemption_logs, :redeemer_type_temp, :redeemer_type
    
    # Step 5: Add index for polymorphic association
    add_index :voucher_redemption_logs, [:redeemer_type, :redeemer_id], 
              name: 'index_voucher_redemption_logs_on_redeemer'
  end
  
  def down
    # Reverse the migration
    add_column :voucher_redemption_logs, :redeemer_type_temp, :integer, limit: 2
    add_column :voucher_redemption_logs, :polymorphic_redeemer_type, :string
    
    # Migrate data back
    VoucherRedemptionLog.reset_column_information
    VoucherRedemptionLog.find_each do |log|
      case log.redeemer_type
      when 'User'
        log.update_columns(redeemer_type_temp: 0, polymorphic_redeemer_type: 'User')
      when 'Visitor'
        log.update_columns(redeemer_type_temp: 1, polymorphic_redeemer_type: 'Visitor')
      end
    end
    
    remove_index :voucher_redemption_logs, name: 'index_voucher_redemption_logs_on_redeemer'
    remove_column :voucher_redemption_logs, :redeemer_type
    rename_column :voucher_redemption_logs, :redeemer_type_temp, :redeemer_type
  end
end
