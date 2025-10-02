class CreateUserMutes < ActiveRecord::Migration[8.0]
  def change
    create_table :user_mutes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :discord_id, null: false
      t.string :moderator_discord_id, null: false
      t.string :guild_id, null: false
      t.text :reason
      t.datetime :muted_at, null: false
      t.datetime :unmuted_at
      t.integer :duration_minutes, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :user_mutes, :discord_id
    add_index :user_mutes, :guild_id
    add_index :user_mutes, [ :discord_id, :guild_id, :active ]
    add_index :user_mutes, :active
    add_index :user_mutes, :unmuted_at
  end
end
