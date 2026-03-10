class AddSeatingAnnouncementTemplateToCheckInDisplays < ActiveRecord::Migration[8.0]
  def change
    add_column :check_in_displays, :seating_announcement_template, :string
  end
end
