class CreateUserWarnings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_warnings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :discord_id, null: false
      t.string :moderator_discord_id, null: false
      t.string :guild_id, null: false
      t.text :reason
      t.datetime :warned_at, null: false

      t.timestamps
    end

    add_index :user_warnings, :discord_id
    add_index :user_warnings, :guild_id
    add_index :user_warnings, [ :discord_id, :guild_id ]
    add_index :user_warnings, :warned_at
  end
end
