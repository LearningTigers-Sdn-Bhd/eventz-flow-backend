class AddDefaultSlotDurationToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_default_slot_duration, :integer, default: 30, null: false
  end
end
