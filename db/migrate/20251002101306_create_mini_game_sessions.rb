class CreateMiniGameSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :mini_game_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :game_type, null: false
      t.integer :bet_amount, null: false
      t.string :result, null: false
      t.integer :winnings, default: 0, null: false
      t.json :metadata, default: {}
      t.datetime :played_at, null: false

      t.timestamps
    end

    add_index :mini_game_sessions, :game_type
    add_index :mini_game_sessions, :played_at
    add_index :mini_game_sessions, [:user_id, :played_at]
  end
end
