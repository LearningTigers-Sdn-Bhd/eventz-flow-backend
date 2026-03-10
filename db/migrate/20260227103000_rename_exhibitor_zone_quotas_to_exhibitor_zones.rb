class RenameExhibitorZoneQuotasToExhibitorZones < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key :exhibitor_booth_prices, :exhibitor_zone_quotas

    rename_table :exhibitor_zone_quotas, :exhibitor_zones
    rename_column :exhibitor_booth_prices, :exhibitor_zone_quota_id, :exhibitor_zone_id

    change_column_null :exhibitor_zones, :quota, true

    if index_name_exists?(:exhibitor_booth_prices, 'index_exhibitor_booth_prices_on_exhibitor_zone_quota_id')
      rename_index :exhibitor_booth_prices,
                   'index_exhibitor_booth_prices_on_exhibitor_zone_quota_id',
                   'index_exhibitor_booth_prices_on_exhibitor_zone_id'
    end
    if index_name_exists?(:exhibitor_zones, 'index_exhibitor_zone_quotas_on_event_id')
      rename_index :exhibitor_zones,
                   'index_exhibitor_zone_quotas_on_event_id',
                   'index_exhibitor_zones_on_event_id'
    end

    remove_index :exhibitor_booth_prices, name: 'idx_exhibitor_booth_prices_unique'
    add_index :exhibitor_booth_prices,
              %i[event_id booth_type exhibitor_zone_id label],
              unique: true,
              name: 'idx_exhibitor_booth_prices_unique'

    remove_index :exhibitor_zones, name: 'idx_exhibitor_zone_quotas_unique'
    add_index :exhibitor_zones,
              %i[event_id zone],
              unique: true,
              name: 'idx_exhibitor_zones_unique'

    add_foreign_key :exhibitor_booth_prices, :exhibitor_zones
  end

  def down
    remove_foreign_key :exhibitor_booth_prices, :exhibitor_zones

    remove_index :exhibitor_booth_prices, name: 'idx_exhibitor_booth_prices_unique'

    rename_column :exhibitor_booth_prices, :exhibitor_zone_id, :exhibitor_zone_quota_id
    if index_name_exists?(:exhibitor_booth_prices, 'index_exhibitor_booth_prices_on_exhibitor_zone_id')
      rename_index :exhibitor_booth_prices,
                   'index_exhibitor_booth_prices_on_exhibitor_zone_id',
                   'index_exhibitor_booth_prices_on_exhibitor_zone_quota_id'
    end

    add_index :exhibitor_booth_prices,
              %i[event_id booth_type exhibitor_zone_quota_id label],
              unique: true,
              name: 'idx_exhibitor_booth_prices_unique'

    remove_index :exhibitor_zones, name: 'idx_exhibitor_zones_unique'
    add_index :exhibitor_zones,
              %i[event_id zone],
              unique: true,
              name: 'idx_exhibitor_zone_quotas_unique'

    if index_name_exists?(:exhibitor_zones, 'index_exhibitor_zones_on_event_id')
      rename_index :exhibitor_zones,
                   'index_exhibitor_zones_on_event_id',
                   'index_exhibitor_zone_quotas_on_event_id'
    end

    change_column_null :exhibitor_zones, :quota, false

    rename_table :exhibitor_zones, :exhibitor_zone_quotas

    add_foreign_key :exhibitor_booth_prices, :exhibitor_zone_quotas
  end
end
