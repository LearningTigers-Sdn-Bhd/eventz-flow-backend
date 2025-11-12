class RenameUserEngageVendorsToVisitorVendorStamps < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:user_engage_vendors)

    # Drop foreign keys first to allow record deletion
    if foreign_key_exists?(:user_engage_vendors, :vendor_profiles)
      remove_foreign_key :user_engage_vendors, :vendor_profiles
    end
    if foreign_key_exists?(:user_engage_vendors, :tickets)
      remove_foreign_key :user_engage_vendors, :tickets
    end
    if foreign_key_exists?(:user_engage_vendors, :event_vendors)
      remove_foreign_key :user_engage_vendors, :event_vendors
    end
    # Remove event_vendor_engagement reference if it exists
    if column_exists?(:user_engage_vendors, :event_vendor_engagement_id)
      if foreign_key_exists?(:user_engage_vendors, column: :event_vendor_engagement_id)
        remove_foreign_key :user_engage_vendors, column: :event_vendor_engagement_id
      end
    end

    # Delete all existing user_engage_vendor records since they are ticket-based
    # and we're migrating to visitor-based stamps (different entities)
    execute "DELETE FROM user_engage_vendors"

    # Rename the table
    rename_table :user_engage_vendors, :visitor_vendor_stamps

    # Remove vendor_profile_id column
    remove_column :visitor_vendor_stamps, :vendor_profile_id, :bigint if column_exists?(:visitor_vendor_stamps, :vendor_profile_id)

    # Remove ticket_id column
    remove_column :visitor_vendor_stamps, :ticket_id, :bigint if column_exists?(:visitor_vendor_stamps, :ticket_id)

    # Remove event_vendor_engagement_id column
    remove_column :visitor_vendor_stamps, :event_vendor_engagement_id, :bigint if column_exists?(:visitor_vendor_stamps, :event_vendor_engagement_id)

    # Remove old indexes
    remove_index :visitor_vendor_stamps, :ticket_id if index_exists?(:visitor_vendor_stamps, :ticket_id)
    remove_index :visitor_vendor_stamps, :vendor_profile_id if index_exists?(:visitor_vendor_stamps, :vendor_profile_id)

    # Add visitor_id column
    add_reference :visitor_vendor_stamps, :visitor, null: false, foreign_key: true unless column_exists?(:visitor_vendor_stamps, :visitor_id)

    # Add unique index on visitor_id and event_vendor_id
    unless index_exists?(:visitor_vendor_stamps, [:visitor_id, :event_vendor_id])
      add_index :visitor_vendor_stamps, [:visitor_id, :event_vendor_id], unique: true, name: 'index_visitor_vendor_stamps_on_visitor_and_event_vendor'
    end

    # Remove time_away_duration if it exists (not needed for stamps)
    remove_column :visitor_vendor_stamps, :time_away_duration, :integer if column_exists?(:visitor_vendor_stamps, :time_away_duration)
  end

  def down
    # Add back time_away_duration
    add_column :visitor_vendor_stamps, :time_away_duration, :integer unless column_exists?(:visitor_vendor_stamps, :time_away_duration)

    # Remove visitor_id
    remove_index :visitor_vendor_stamps, name: 'index_visitor_vendor_stamps_on_visitor_and_event_vendor' if index_exists?(:visitor_vendor_stamps, [:visitor_id, :event_vendor_id])
    remove_foreign_key :visitor_vendor_stamps, :visitors if foreign_key_exists?(:visitor_vendor_stamps, :visitors)
    remove_column :visitor_vendor_stamps, :visitor_id, :bigint if column_exists?(:visitor_vendor_stamps, :visitor_id)

    # Add back ticket_id
    add_reference :visitor_vendor_stamps, :ticket, null: false, foreign_key: true unless column_exists?(:visitor_vendor_stamps, :ticket_id)
    add_index :visitor_vendor_stamps, :ticket_id unless index_exists?(:visitor_vendor_stamps, :ticket_id)

    # Add back vendor_profile_id
    add_reference :visitor_vendor_stamps, :vendor_profile, null: false, foreign_key: true unless column_exists?(:visitor_vendor_stamps, :vendor_profile_id)
    add_index :visitor_vendor_stamps, :vendor_profile_id unless index_exists?(:visitor_vendor_stamps, :vendor_profile_id)

    # Rename table back
    rename_table :visitor_vendor_stamps, :user_engage_vendors
  end
end
