class CreateCertificateTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :certificate_templates do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0 # 0=draft 1=ready 2=archived
      t.string  :orientation, null: false, default: "landscape"
      t.integer :canvas_width, null: false, default: 1123 # A4 landscape @96dpi
      t.integer :canvas_height, null: false, default: 794
      t.jsonb   :fields, null: false, default: []
      t.timestamps
    end

    add_index :certificate_templates, :status
  end
end
