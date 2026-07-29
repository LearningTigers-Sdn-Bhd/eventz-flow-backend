class AddUniqueRegistrationFieldIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  KEYS = %w[membership_no ic_passport_no].freeze

  def up
    KEYS.each do |key|
      add_index :tickets,
                "event_id, lower(custom_fields_data->>'#{key}')",
                name: "idx_tickets_unique_#{key}",
                unique: true,
                where: "deleted_at IS NULL AND status <> 3 AND nullif(custom_fields_data->>'#{key}', '') IS NOT NULL",
                algorithm: :concurrently
    end
  end

  def down
    KEYS.each do |key|
      remove_index :tickets, name: "idx_tickets_unique_#{key}", algorithm: :concurrently
    end
  end
end
