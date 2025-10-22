class CreateModeratorRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :moderator_roles do |t|
      t.references :stream, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :can_timeout_users, default: false, null: false
      t.boolean :can_ban_users, default: false, null: false
      t.boolean :can_delete_messages, default: false, null: false
      t.boolean :can_manage_slow_mode, default: false, null: false
      t.boolean :can_manage_emote_only, default: false, null: false
      t.boolean :can_manage_moderators, default: false, null: false
      t.text :description

      t.timestamps
    end

    add_index :moderator_roles, [:stream_id, :name], unique: true
  end
end
