class ConvertExhibitorKitBoothTypeToString < ActiveRecord::Migration[8.0]
  def up
    add_column :exhibitor_kits, :booth_type_string, :string

    execute <<-SQL.squish
      UPDATE exhibitor_kits
      SET booth_type_string = CASE booth_type
        WHEN 0 THEN 'shell_scheme'
        WHEN 1 THEN 'raw_space'
      END
    SQL

    remove_column :exhibitor_kits, :booth_type
    rename_column :exhibitor_kits, :booth_type_string, :booth_type

    add_column :events, :booth_types, :jsonb, default: []
  end

  def down
    remove_column :events, :booth_types

    add_column :exhibitor_kits, :booth_type_integer, :integer

    execute <<-SQL.squish
      UPDATE exhibitor_kits
      SET booth_type_integer = CASE booth_type
        WHEN 'shell_scheme' THEN 0
        WHEN 'raw_space' THEN 1
      END
    SQL

    remove_column :exhibitor_kits, :booth_type
    rename_column :exhibitor_kits, :booth_type_integer, :booth_type
  end
end
