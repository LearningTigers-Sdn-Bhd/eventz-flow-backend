class AddExtraGuestLimitToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :extra_guest_limit, :integer
  end
end
