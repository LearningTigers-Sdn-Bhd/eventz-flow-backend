class AddZoneToExhibitorBoothPricesAndCreateZoneQuotas < ActiveRecord::Migration[7.2]
  def up
    create_table :exhibitor_zone_quotas do |t|
      t.references :event, null: false, foreign_key: true
      t.string :zone, null: false
      t.integer :quota, null: false

      t.timestamps
    end

    add_index :exhibitor_zone_quotas, [:event_id, :zone], unique: true, name: "idx_exhibitor_zone_quotas_unique"

    add_reference :exhibitor_booth_prices,
                  :exhibitor_zone_quota,
                  null: true,
                  foreign_key: { to_table: :exhibitor_zone_quotas }

    remove_index :exhibitor_booth_prices, name: "idx_exhibitor_booth_prices_unique"
    add_index :exhibitor_booth_prices,
              [:event_id, :booth_type, :exhibitor_zone_quota_id, :label],
              unique: true,
              name: "idx_exhibitor_booth_prices_unique"
  end

  def down
    remove_index :exhibitor_booth_prices, name: "idx_exhibitor_booth_prices_unique"
    add_index :exhibitor_booth_prices,
              [:event_id, :booth_type, :label],
              unique: true,
              name: "idx_exhibitor_booth_prices_unique"

    remove_reference :exhibitor_booth_prices,
                     :exhibitor_zone_quota,
                     foreign_key: { to_table: :exhibitor_zone_quotas }

    drop_table :exhibitor_zone_quotas
  end
end
