class AddConferencesIncludedToExhibitorBoothPrices < ActiveRecord::Migration[7.2]
  def change
    add_column :exhibitor_booth_prices, :conferences_included, :boolean, null: false, default: false
  end
end
