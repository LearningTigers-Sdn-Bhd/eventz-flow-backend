class AllowMultipleCertificateTemplatesPerEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_templates, :name, :string, null: false, default: 'Default'
    # Ticket types this template applies to. Empty = the event's default template.
    add_column :certificate_templates, :ticket_type_ids, :bigint, array: true, null: false, default: []

    remove_index :certificate_templates, :event_id, unique: true
    add_index :certificate_templates, :event_id
  end
end
