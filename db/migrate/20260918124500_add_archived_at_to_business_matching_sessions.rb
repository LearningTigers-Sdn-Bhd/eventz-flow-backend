# frozen_string_literal: true

class AddArchivedAtToBusinessMatchingSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :business_matching_sessions, :archived_at, :datetime
    add_index :business_matching_sessions, :archived_at
  end
end
