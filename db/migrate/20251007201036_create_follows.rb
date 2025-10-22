class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followee, null: false, foreign_key: { to_table: :users }
      t.boolean :notifications_enabled, default: true

      t.timestamps
    end

    # Ensure a user can only follow another user once
    add_index :follows, [:follower_id, :followee_id], unique: true
  end
end
