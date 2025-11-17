class MakeEventVendorRedirectUrlNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :event_vendors, :redirect_url, true
  end
end
