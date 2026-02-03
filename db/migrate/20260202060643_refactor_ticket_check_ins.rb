class RefactorTicketCheckIns < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Create ticket_check_ins table
    create_table :ticket_check_ins do |t|
      t.references :ticket, null: false, foreign_key: true
      t.datetime :check_in_at, null: false
      t.references :scanned_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    # Unique constraint: one check-in per ticket per day
    add_index :ticket_check_ins, 'ticket_id, DATE(check_in_at)',
              unique: true,
              name: 'idx_ticket_check_ins_unique_per_day'

    # Step 2: Migrate existing check-in data
    execute <<-SQL
      INSERT INTO ticket_check_ins (ticket_id, check_in_at, scanned_by_id, created_at, updated_at)
      SELECT id, check_in_at, scanned_by_id, check_in_at, check_in_at
      FROM tickets
      WHERE checked_in = true AND check_in_at IS NOT NULL
    SQL

    # Step 3: Remove old columns from tickets
    remove_column :tickets, :check_in_at
    remove_column :tickets, :scanned_by_id
  end

  def down
    # Add columns back
    add_column :tickets, :check_in_at, :datetime
    add_column :tickets, :scanned_by_id, :bigint
    add_index :tickets, :scanned_by_id
    add_foreign_key :tickets, :users, column: :scanned_by_id

    # Restore data from first check-in record
    execute <<-SQL
      UPDATE tickets
      SET check_in_at = tci.check_in_at,
          scanned_by_id = tci.scanned_by_id
      FROM (
        SELECT DISTINCT ON (ticket_id) ticket_id, check_in_at, scanned_by_id
        FROM ticket_check_ins
        ORDER BY ticket_id, check_in_at ASC
      ) tci
      WHERE tickets.id = tci.ticket_id
    SQL

    # Drop table
    drop_table :ticket_check_ins
  end
end
