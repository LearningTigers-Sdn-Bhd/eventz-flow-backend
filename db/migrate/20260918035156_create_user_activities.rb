# frozen_string_literal: true

class CreateUserActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :category, null: false, default: 'general' # e.g., 'business_matching', 'check_in', 'event', 'auth'
      t.string :action_name, null: false                   # Friendly name, e.g., "Rescheduled Matchmaking Appointment"
      t.string :http_method, null: false                  # GET, POST, PATCH, DELETE
      t.string :path, null: false                         # Normalized or actual path
      t.jsonb :details, default: {}, null: false          # Safe summary of params / resource details
      t.string :ip_address
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :user_activities, :created_at
    add_index :user_activities, [:user_id, :created_at]
    add_index :user_activities, :category
  end
end
