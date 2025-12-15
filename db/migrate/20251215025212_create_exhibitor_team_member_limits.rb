class CreateExhibitorTeamMemberLimits < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_team_member_limits do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.integer :team_member_limit
      t.decimal :extra_team_member_fee, precision: 10, scale: 2, default: 0.00

      t.timestamps
    end
  end
end
