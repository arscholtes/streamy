class CreateGameSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :game_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :stream, foreign_key: true, index: true
      t.string :platform
      t.string :game_name
      t.string :game_id
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.json :metadata

      t.timestamps
    end

    add_index :game_sessions, :platform
    add_index :game_sessions, :started_at
    add_index :game_sessions, [:user_id, :started_at]
  end
end
