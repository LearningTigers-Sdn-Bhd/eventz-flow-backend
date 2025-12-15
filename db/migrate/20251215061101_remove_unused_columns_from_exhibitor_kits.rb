# This migration removes columns from exhibitor_kits that have been replaced
# by dedicated tables with better structure:
#
# - extra_crew_count -> exhibitor_team_members + exhibitor_team_member_limits
# - contractor_* columns -> exhibition_contractor_profiles
# - furniture_requests, electrical_requests -> exhibitor_kit_items
# - printing_orders -> exhibitor_kit_printings
# - stand_design_file_url -> custom_requests or exhibitor_kit_printings.file_reference
class RemoveUnusedColumnsFromExhibitorKits < ActiveRecord::Migration[8.0]
  def change
    # Remove extra_crew_count - replaced by exhibitor_team_members table
    remove_column :exhibitor_kits, :extra_crew_count, :integer, default: 0

    # Remove contractor columns - replaced by exhibition_contractor_profiles table
    remove_column :exhibitor_kits, :contractor_company_name, :string
    remove_column :exhibitor_kits, :contractor_pic_name, :string
    remove_column :exhibitor_kits, :contractor_pic_contact, :string

    # Remove stand_design_file_url - can be handled via custom_requests or exhibitor_kit_printings
    remove_column :exhibitor_kits, :stand_design_file_url, :string

    # Remove JSON request columns - replaced by exhibitor_kit_items table
    remove_column :exhibitor_kits, :furniture_requests, :json
    remove_column :exhibitor_kits, :electrical_requests, :json

    # Remove printing_orders - replaced by exhibitor_kit_printings table
    remove_column :exhibitor_kits, :printing_orders, :json
  end
end
