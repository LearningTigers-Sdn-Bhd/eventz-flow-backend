class AddContactAndAttendeeFieldsToExhibitorTeamMembers < ActiveRecord::Migration[8.0]
  def change
    change_table :exhibitor_team_members, bulk: true do |t|
      t.string :email
      t.string :phone
      t.string :attendee_type
      t.bigint :attendee_id
    end

    add_index :exhibitor_team_members, %i[attendee_type attendee_id], name: 'index_exhibitor_team_members_on_attendee'
  end
end
