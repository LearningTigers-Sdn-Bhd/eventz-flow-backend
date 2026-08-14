class AddBusinessMatchingAutoApproveToEvents < ActiveRecord::Migration[8.0]
  COLUMN = :business_matching_auto_approve_bookings

  # Defaults to true so existing events keep the behaviour they had before this
  # setting existed: bookings confirmed the moment they're made.
  #
  # Guarded because some databases already picked this column up out-of-band
  # (with a `false` default) from a migration that never landed in this repo —
  # this normalises them instead of blowing up on a duplicate column.
  def up
    if column_exists?(:events, COLUMN)
      change_column_default :events, COLUMN, true
      Event.where(COLUMN => false).update_all(COLUMN => true)
    else
      add_column :events, COLUMN, :boolean, default: true, null: false
    end
  end

  def down
    remove_column :events, COLUMN if column_exists?(:events, COLUMN)
  end
end
