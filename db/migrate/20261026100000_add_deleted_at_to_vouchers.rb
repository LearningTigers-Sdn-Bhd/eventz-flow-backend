class AddDeletedAtToVouchers < ActiveRecord::Migration[8.0]
  def change
    # Soft delete (archive), same as tickets. NULL = live.
    add_column :vouchers, :deleted_at, :datetime
    add_index :vouchers, :deleted_at
  end
end
