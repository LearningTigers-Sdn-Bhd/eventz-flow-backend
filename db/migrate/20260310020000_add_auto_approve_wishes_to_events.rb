class AddAutoApproveWishesToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :auto_approve_wishes, :boolean, null: false, default: false
  end
end
