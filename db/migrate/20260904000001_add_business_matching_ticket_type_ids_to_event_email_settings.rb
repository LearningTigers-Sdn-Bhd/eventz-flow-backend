class AddBusinessMatchingTicketTypeIdsToEventEmailSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :event_email_settings, :business_matching_ticket_type_ids, :jsonb, null: false, default: []
  end
end
