class CreateTiktokAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :tiktok_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :tiktok_id
      t.string :username
      t.string :display_name
      t.integer :follower_count
      t.integer :video_count
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :tiktok_accounts, :tiktok_id, unique: true
  end
end
