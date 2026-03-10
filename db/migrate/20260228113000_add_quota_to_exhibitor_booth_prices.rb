class AddQuotaToExhibitorBoothPrices < ActiveRecord::Migration[7.2]
  def change
    add_column :exhibitor_booth_prices, :quota, :integer
  end
end
