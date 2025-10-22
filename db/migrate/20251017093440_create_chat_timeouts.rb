class CreateChatTimeouts < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_timeouts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stream, null: false, foreign_key: true
      t.integer :timed_out_by_id, null: false
      t.text :reason
      t.datetime :timed_out_at, null: false
      t.datetime :expires_at, null: false
      t.integer :duration_seconds, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :chat_timeouts, [:user_id, :stream_id, :active]
    add_index :chat_timeouts, :timed_out_by_id
    add_index :chat_timeouts, :expires_at
    add_foreign_key :chat_timeouts, :users, column: :timed_out_by_id
  end
end
