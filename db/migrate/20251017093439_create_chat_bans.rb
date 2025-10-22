class CreateChatBans < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_bans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stream, null: false, foreign_key: true
      t.integer :banned_by_id, null: false
      t.text :reason
      t.datetime :banned_at, null: false
      t.datetime :expires_at
      t.boolean :permanent, default: false, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :chat_bans, [:user_id, :stream_id, :active]
    add_index :chat_bans, :banned_by_id
    add_index :chat_bans, :expires_at
    add_foreign_key :chat_bans, :users, column: :banned_by_id
  end
end
