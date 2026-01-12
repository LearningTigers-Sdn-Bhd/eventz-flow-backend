class AddAuditColumnsToSponsorshipTables < ActiveRecord::Migration[8.0]
  def change
    add_reference :event_sponsorship_payments, :created_by, foreign_key: { to_table: :users }
    add_reference :event_sponsorship_payments, :updated_by, foreign_key: { to_table: :users }
    
    add_reference :event_sponsorship_items, :created_by, foreign_key: { to_table: :users }
    add_reference :event_sponsorship_items, :updated_by, foreign_key: { to_table: :users }
  end
end