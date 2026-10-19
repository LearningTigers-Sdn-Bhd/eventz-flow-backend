class AddAudienceToCertificateTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_templates, :audience, :string, null: false, default: 'ticket'
    add_index :certificate_templates, :event_id, unique: true, where: "audience = 'exhibitor'",
              name: 'idx_certificate_templates_one_exhibitor_per_event'
  end
end
