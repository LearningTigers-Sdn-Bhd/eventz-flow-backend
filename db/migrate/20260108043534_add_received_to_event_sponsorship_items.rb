class AddReceivedToEventSponsorshipItems < ActiveRecord::Migration[8.0]
  def change
    add_column :event_sponsorship_items, :received, :boolean
  end
end
