class BackfillTicketNormalizedColumns < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Populate attendee_email_norm while avoiding unique conflicts: keep first per (event_id, email_norm), nullify others
    execute <<~SQL
      WITH prepared AS (
        SELECT id,
               event_id,
               NULLIF(LOWER(BTRIM(attendee_email)), '') AS email_norm,
               ROW_NUMBER() OVER (
                 PARTITION BY event_id, NULLIF(LOWER(BTRIM(attendee_email)), '')
                 ORDER BY id ASC
               ) AS rn
        FROM tickets
      )
      UPDATE tickets AS t
      SET attendee_email_norm = CASE
        WHEN p.email_norm IS NULL THEN NULL
        WHEN p.rn = 1 THEN p.email_norm
        ELSE NULL
      END
      FROM prepared p
      WHERE t.id = p.id;
    SQL

    # Populate attendee_phone_norm while avoiding unique conflicts: keep first per (event_id, phone_norm), nullify others
    execute <<~SQL
      WITH prepared AS (
        SELECT id,
               event_id,
               NULLIF(regexp_replace(attendee_phone, '\\D+', '', 'g'), '') AS phone_norm,
               ROW_NUMBER() OVER (
                 PARTITION BY event_id, NULLIF(regexp_replace(attendee_phone, '\\D+', '', 'g'), '')
                 ORDER BY id ASC
               ) AS rn
        FROM tickets
      )
      UPDATE tickets AS t
      SET attendee_phone_norm = CASE
        WHEN p.phone_norm IS NULL THEN NULL
        WHEN p.rn = 1 THEN p.phone_norm
        ELSE NULL
      END
      FROM prepared p
      WHERE t.id = p.id;
    SQL

    # Populate attendee_name_norm (normalized, spaces collapsed, lowercased) while enforcing uniqueness only when email/phone norms are null
    # For duplicates per (event_id, ticket_type_id, name_norm) where email_norm and phone_norm are both NULL, keep first and nullify others
    execute <<~SQL
      WITH prepared AS (
        SELECT id,
               event_id,
               ticket_type_id,
               NULLIF(LOWER(regexp_replace(BTRIM(attendee_name), '\\s+', ' ', 'g')), '') AS name_norm,
               ROW_NUMBER() OVER (
                 PARTITION BY event_id, ticket_type_id, NULLIF(LOWER(regexp_replace(BTRIM(attendee_name), '\\s+', ' ', 'g')), '')
                 ORDER BY id ASC
               ) AS rn
        FROM tickets
        WHERE COALESCE(attendee_email_norm, '') = '' AND COALESCE(attendee_phone_norm, '') = ''
      )
      UPDATE tickets AS t
      SET attendee_name_norm = CASE
        WHEN p.name_norm IS NULL THEN NULL
        WHEN p.rn = 1 THEN p.name_norm
        ELSE NULL
      END
      FROM prepared p
      WHERE t.id = p.id;

      -- For rows where email_norm or phone_norm exists, still set name_norm (not part of uniqueness in that branch)
      UPDATE tickets
      SET attendee_name_norm = NULLIF(LOWER(regexp_replace(BTRIM(attendee_name), '\\s+', ' ', 'g')), '')
      WHERE (attendee_email_norm IS NOT NULL OR attendee_phone_norm IS NOT NULL)
        AND attendee_name IS NOT NULL;
    SQL
  end

  def down
    # No-op: keep normalized data; dropping columns is handled by schema rollback if needed
  end
end
