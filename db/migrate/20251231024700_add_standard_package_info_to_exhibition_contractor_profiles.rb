class AddStandardPackageInfoToExhibitionContractorProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :exhibition_contractor_profiles, :standard_package_info, :text
  end
end
