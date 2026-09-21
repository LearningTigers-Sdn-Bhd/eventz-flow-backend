# frozen_string_literal: true

class AddAiDiagnosisToUserActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :user_activities, :ai_diagnosis, :jsonb
    add_column :user_activities, :ai_diagnosed_at, :datetime
  end
end
