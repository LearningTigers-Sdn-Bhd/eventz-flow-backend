class RemoveImagePathFromVouchers < ActiveRecord::Migration[8.0]
  def change
    remove_column :vouchers, :image_path, :string
  end
end
