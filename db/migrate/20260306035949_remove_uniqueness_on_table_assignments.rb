class RemoveUniquenessOnTableAssignments < ActiveRecord::Migration[8.0]
  def change
    remove_index :table_assignments, :ticket_id if index_exists?(:table_assignments, :ticket_id)
    remove_index :table_assignments, :visitor_id if index_exists?(:table_assignments, :visitor_id)
    
    add_index :table_assignments, :ticket_id
    add_index :table_assignments, :visitor_id
  end
end
