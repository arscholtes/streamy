class CreateSpotifyAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :spotify_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :spotify_id
      t.string :display_name
      t.string :email
      t.string :product
      t.string :country
      t.integer :follower_count
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :spotify_accounts, :spotify_id, unique: true
  end
end
