class CreateExhibitorTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_team_members do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.string :full_name

      t.timestamps
    end
  end
end
