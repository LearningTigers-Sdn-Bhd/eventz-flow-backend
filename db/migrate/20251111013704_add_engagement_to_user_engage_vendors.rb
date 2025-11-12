class AddEngagementToUserEngageVendors < ActiveRecord::Migration[8.0]
  def change
    add_reference :user_engage_vendors, :event_vendor_engagement, foreign_key: true, null: true
  end
end
