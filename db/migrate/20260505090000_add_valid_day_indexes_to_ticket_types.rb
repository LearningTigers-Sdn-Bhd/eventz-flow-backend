class AddValidDayIndexesToTicketTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :ticket_types, :valid_day_indexes, :integer, array: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE ticket_types
          SET valid_day_indexes = ARRAY[1]::integer[]
          WHERE event_id IS NOT NULL
            AND valid_day_indexes IS NULL
        SQL
      end
    end
  end
end
