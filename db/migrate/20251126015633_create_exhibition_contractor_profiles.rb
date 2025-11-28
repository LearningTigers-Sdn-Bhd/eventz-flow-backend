class CreateExhibitionContractorProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibition_contractor_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name
      t.string :contact_person
      t.string :contact_email
      t.string :contact_phone

      t.timestamps
    end
  end
end
