class UpdateTableAssignmentsForVisitors < ActiveRecord::Migration[8.0]
  def change
    add_reference :table_assignments, :visitor, null: true, foreign_key: true, index: false unless column_exists?(:table_assignments, :visitor_id)
    
    # Add index if it doesn't exist
    unless index_exists?(:table_assignments, :visitor_id)
      add_index :table_assignments, :visitor_id, unique: true, where: "visitor_id IS NOT NULL"
    end

    # Allow ticket_id to be null
    change_column_null :table_assignments, :ticket_id, true

    # Add check constraint to ensure exactly one is present
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE table_assignments 
          ADD CONSTRAINT table_assignments_exactly_one_participant 
          CHECK (
            (ticket_id IS NOT NULL AND visitor_id IS NULL) OR 
            (ticket_id IS NULL AND visitor_id IS NOT NULL)
          );
        SQL
      end
      dir.down do
        execute <<-SQL
          ALTER TABLE table_assignments 
          DROP CONSTRAINT table_assignments_exactly_one_participant;
        SQL
      end
    end
  end
end