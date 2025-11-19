class AddQrUrlToEventVendors < ActiveRecord::Migration[8.0]
  def change
    add_column :event_vendors, :qr_url, :string
  end
end
