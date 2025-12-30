class AddAllowPrintingServicesToExhibitionContractorProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :exhibition_contractor_profiles, :allow_printing_services, :boolean, default: true, null: false
  end
end
