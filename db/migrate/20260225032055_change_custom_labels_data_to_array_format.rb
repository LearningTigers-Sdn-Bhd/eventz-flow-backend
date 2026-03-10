class ChangeCustomLabelsDataToArrayFormat < ActiveRecord::Migration[8.0]
  def up
    # Convert existing hash data to array format on registration_forms
    execute <<-SQL
      UPDATE registration_forms
      SET custom_labels_data = (
        SELECT COALESCE(
          jsonb_agg(jsonb_build_object('key', kv.key, 'label', kv.value) ORDER BY kv.key),
          '[]'::jsonb
        )
        FROM jsonb_each_text(custom_labels_data) AS kv(key, value)
      )
      WHERE custom_labels_data IS NOT NULL
        AND custom_labels_data != '{}'::jsonb
    SQL

    # Set empty hash rows to empty array
    execute <<-SQL
      UPDATE registration_forms
      SET custom_labels_data = '[]'::jsonb
      WHERE custom_labels_data = '{}'::jsonb
    SQL

    # Convert existing hash data to array format on registration_form_ticket_types
    execute <<-SQL
      UPDATE registration_form_ticket_types
      SET custom_labels_data = (
        SELECT COALESCE(
          jsonb_agg(jsonb_build_object('key', kv.key, 'label', kv.value) ORDER BY kv.key),
          '[]'::jsonb
        )
        FROM jsonb_each_text(custom_labels_data) AS kv(key, value)
      )
      WHERE custom_labels_data IS NOT NULL
        AND custom_labels_data != '{}'::jsonb
    SQL

    # Set empty hash rows to empty array
    execute <<-SQL
      UPDATE registration_form_ticket_types
      SET custom_labels_data = '[]'::jsonb
      WHERE custom_labels_data = '{}'::jsonb
    SQL

    # Change defaults to empty array
    change_column_default :registration_forms, :custom_labels_data, from: {}, to: []
    change_column_default :registration_form_ticket_types, :custom_labels_data, from: {}, to: []
  end

  def down
    # Convert array data back to hash format on registration_forms
    execute <<-SQL
      UPDATE registration_forms
      SET custom_labels_data = (
        SELECT COALESCE(
          jsonb_object_agg(elem->>'key', elem->>'label'),
          '{}'::jsonb
        )
        FROM jsonb_array_elements(custom_labels_data) AS elem
      )
      WHERE custom_labels_data IS NOT NULL
        AND custom_labels_data != '[]'::jsonb
    SQL

    execute <<-SQL
      UPDATE registration_forms
      SET custom_labels_data = '{}'::jsonb
      WHERE custom_labels_data = '[]'::jsonb
    SQL

    # Convert array data back to hash format on registration_form_ticket_types
    execute <<-SQL
      UPDATE registration_form_ticket_types
      SET custom_labels_data = (
        SELECT COALESCE(
          jsonb_object_agg(elem->>'key', elem->>'label'),
          '{}'::jsonb
        )
        FROM jsonb_array_elements(custom_labels_data) AS elem
      )
      WHERE custom_labels_data IS NOT NULL
        AND custom_labels_data != '[]'::jsonb
    SQL

    execute <<-SQL
      UPDATE registration_form_ticket_types
      SET custom_labels_data = '{}'::jsonb
      WHERE custom_labels_data = '[]'::jsonb
    SQL

    # Change defaults back to empty hash
    change_column_default :registration_forms, :custom_labels_data, from: [], to: {}
    change_column_default :registration_form_ticket_types, :custom_labels_data, from: [], to: {}
  end
end
