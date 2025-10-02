class CreateDiscordAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :discord_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :discord_id
      t.string :username
      t.string :discriminator
      t.string :avatar_url
      t.string :email
      t.boolean :verified
      t.string :locale
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :discord_accounts, :discord_id, unique: true
  end
end
