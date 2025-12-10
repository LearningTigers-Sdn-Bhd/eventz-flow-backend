class CreateLuckyDrawTables < ActiveRecord::Migration[8.0]
  def change
    # Create lucky_draw_sessions table
    create_table :lucky_draw_sessions do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.date :draw_date, null: true
      t.string :logo, null: true
      t.jsonb :draw_styles, default: {}
      t.jsonb :wrapper_background, default: {}
      t.boolean :use_gifts, default: false, null: false

      t.timestamps
    end

    add_index :lucky_draw_sessions, :event_id
    add_index :lucky_draw_sessions, :draw_date
    add_index :lucky_draw_sessions, :draw_styles, using: :gin
    add_index :lucky_draw_sessions, :wrapper_background, using: :gin

    # Create gifts table
    create_table :gifts do |t|
      t.references :lucky_draw_session, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :order, default: 0, null: false
      t.integer :winner_counts, default: 0, null: false

      t.timestamps
    end

    add_index :gifts, :lucky_draw_session_id
    add_index :gifts, [:lucky_draw_session_id, :order]

    # Create gift_winners table
    create_table :gift_winners do |t|
      t.references :gift, null: false, foreign_key: true, index: false
      t.references :ticket, null: true, foreign_key: { on_delete: :cascade }, index: false
      t.references :visitor, null: true, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :drawn_at, null: false

      t.timestamps
    end

    add_index :gift_winners, :gift_id
    add_index :gift_winners, :ticket_id
    add_index :gift_winners, :visitor_id

    # Add check constraint: exactly one of ticket_id or visitor_id must be non-null
    add_check_constraint :gift_winners,
      "(ticket_id IS NOT NULL AND visitor_id IS NULL) OR (ticket_id IS NULL AND visitor_id IS NOT NULL)",
      name: "gift_winners_exactly_one_participant"

    # Create invalid_participants table
    create_table :invalid_participants do |t|
      t.references :lucky_draw_session, null: false, foreign_key: true, index: false
      t.references :ticket, null: true, foreign_key: { on_delete: :cascade }, index: false
      t.references :visitor, null: true, foreign_key: { on_delete: :cascade }, index: false

      t.timestamps
    end

    add_index :invalid_participants, :lucky_draw_session_id
    add_index :invalid_participants, :ticket_id
    add_index :invalid_participants, :visitor_id

    # Add check constraint: exactly one of ticket_id or visitor_id must be non-null
    add_check_constraint :invalid_participants,
      "(ticket_id IS NOT NULL AND visitor_id IS NULL) OR (ticket_id IS NULL AND visitor_id IS NOT NULL)",
      name: "invalid_participants_exactly_one_participant"

    # Add unique constraints using partial indexes
    add_index :invalid_participants, [:lucky_draw_session_id, :ticket_id],
      unique: true,
      where: "ticket_id IS NOT NULL",
      name: "index_invalid_participants_on_session_id_and_ticket_id_unique"

    add_index :invalid_participants, [:lucky_draw_session_id, :visitor_id],
      unique: true,
      where: "visitor_id IS NOT NULL",
      name: "index_invalid_participants_on_session_id_and_visitor_id_unique"
  end
end
