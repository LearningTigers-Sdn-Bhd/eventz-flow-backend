class AddImagePathToVouchers < ActiveRecord::Migration[8.0]
  def change
    add_column :vouchers, :image_path, :string
  end
end
