class CreateExhibitorKits < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_kits do |t|
      t.references :event_vendor, null: false, foreign_key: true
      t.string :booth_number
      t.integer :booth_type
      t.string :booth_dimensions
      t.boolean :side_wall_left_required, default: false
      t.boolean :side_wall_right_required, default: false
      t.string :name_on_fascia
      t.boolean :fascia_upgrade_required, default: false
      t.string :company_name
      t.text :company_address
      t.string :pic_full_name
      t.string :pic_contact_number
      t.string :pic_email_address
      t.integer :extra_crew_count, default: 0
      t.text :special_requirements
      t.string :digital_brochure_link
      t.string :qr_code_url
      t.string :contractor_company_name
      t.string :contractor_pic_name
      t.string :contractor_pic_contact
      t.string :stand_design_file_url
      t.json :furniture_requests
      t.json :electrical_requests
      t.json :printing_orders
      t.boolean :indemnity_signed, default: false
      t.string :indemnity_document_url

      t.timestamps
    end
  end
end
