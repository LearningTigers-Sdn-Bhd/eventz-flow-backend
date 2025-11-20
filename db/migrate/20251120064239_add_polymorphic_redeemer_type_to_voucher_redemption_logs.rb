class AddPolymorphicRedeemerTypeToVoucherRedemptionLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :voucher_redemption_logs, :polymorphic_redeemer_type, :string
  end
end
