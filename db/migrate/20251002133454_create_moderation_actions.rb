class CreateModerationActions < ActiveRecord::Migration[8.0]
  def change
    create_table :moderation_actions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action_type, null: false
      t.integer :target_user_id
      t.string :moderator_discord_id, null: false
      t.string :target_discord_id, null: false
      t.text :reason
      t.json :metadata, default: {}
      t.string :guild_id, null: false
      t.datetime :performed_at, null: false

      t.timestamps
    end

    add_index :moderation_actions, :action_type
    add_index :moderation_actions, :target_discord_id
    add_index :moderation_actions, :guild_id
    add_index :moderation_actions, :performed_at
  end
end
