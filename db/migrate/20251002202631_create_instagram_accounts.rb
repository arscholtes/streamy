class CreateInstagramAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :instagram_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :instagram_id
      t.string :username
      t.string :full_name
      t.integer :follower_count
      t.integer :media_count
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :instagram_accounts, :instagram_id, unique: true
  end
end
