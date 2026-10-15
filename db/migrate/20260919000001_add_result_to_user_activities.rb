# frozen_string_literal: true

class AddResultToUserActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :user_activities, :result, :string, default: 'success', null: false
    add_column :user_activities, :error_message, :string
  end
end
