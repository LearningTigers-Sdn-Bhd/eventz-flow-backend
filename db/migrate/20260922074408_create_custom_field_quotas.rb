# frozen_string_literal: true

class CreateCustomFieldQuotas < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_field_quotas do |t|
      t.references :event, null: false, foreign_key: true
      t.string :field_key, null: false
      t.string :value, null: false
      t.integer :quota, null: false

      t.timestamps
    end

    add_index :custom_field_quotas, %i[event_id field_key value], unique: true, name: 'index_custom_field_quotas_on_event_field_value'
  end
end
