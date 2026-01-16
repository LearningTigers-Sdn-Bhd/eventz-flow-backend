class CreateRouletteTables < ActiveRecord::Migration[8.0]
  def change
    # Create roulette_sessions table
    create_table :roulette_sessions do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.date :draw_date, null: true
      t.jsonb :draw_styles, default: {}
      t.jsonb :wrapper_background, default: {}
      t.boolean :is_multiple, default: false, null: false
      t.integer :draw_counts, default: 1, null: false

      t.timestamps
    end

    add_index :roulette_sessions, :event_id
    add_index :roulette_sessions, :user_id
    add_index :roulette_sessions, :draw_date
    add_index :roulette_sessions, :created_at
    add_index :roulette_sessions, :draw_styles, using: :gin
    add_index :roulette_sessions, :wrapper_background, using: :gin

    # Create roulette_assigns table
    create_table :roulette_assigns do |t|
      t.references :roulette_session, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :roulette_assigns, :roulette_session_id
    add_index :roulette_assigns, :user_id
    add_index :roulette_assigns, [:roulette_session_id, :user_id], unique: true

    # Create roulette_prizes table
    create_table :roulette_prizes do |t|
      t.references :roulette_session, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :quantity, default: 0, null: false

      t.timestamps
    end

    add_index :roulette_prizes, :roulette_session_id
    add_index :roulette_prizes, [:roulette_session_id, :created_at]

    # Create roulette_winners table
    create_table :roulette_winners do |t|
      t.references :roulette_session, null: false, foreign_key: true, index: false
      t.references :roulette_prize, null: false, foreign_key: true, index: false
      t.references :ticket, null: true, foreign_key: { on_delete: :cascade }, index: false
      t.references :visitor, null: true, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :drawn_at, null: false

      t.timestamps
    end

    add_index :roulette_winners, :roulette_session_id
    add_index :roulette_winners, :roulette_prize_id
    add_index :roulette_winners, :ticket_id
    add_index :roulette_winners, :visitor_id

    # Add check constraint: exactly one of ticket_id or visitor_id must be non-null
    add_check_constraint :roulette_winners,
      "(ticket_id IS NOT NULL AND visitor_id IS NULL) OR (ticket_id IS NULL AND visitor_id IS NOT NULL)",
      name: "roulette_winners_exactly_one_participant"
  end
end
