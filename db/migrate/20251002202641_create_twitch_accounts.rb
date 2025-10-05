class CreateTwitchAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :twitch_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :twitch_id
      t.string :login
      t.string :display_name
      t.string :broadcaster_type
      t.string :description
      t.string :profile_image_url
      t.integer :view_count
      t.integer :follower_count
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :twitch_accounts, :twitch_id, unique: true
  end
end
