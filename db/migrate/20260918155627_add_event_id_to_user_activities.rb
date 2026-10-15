# frozen_string_literal: true

class AddEventIdToUserActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :user_activities, :event_id, :bigint
    add_index :user_activities, [:event_id, :created_at]
    add_index :user_activities, [:event_id, :category]
  end
end
