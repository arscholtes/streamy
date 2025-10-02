class CreateTwitterAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :twitter_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :twitter_id
      t.string :username
      t.string :name
      t.string :profile_image_url
      t.integer :followers_count
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :twitter_accounts, :twitter_id, unique: true
  end
end
