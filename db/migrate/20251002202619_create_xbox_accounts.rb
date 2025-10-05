class CreateXboxAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :xbox_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :xbox_id
      t.string :gamertag
      t.integer :gamerscore
      t.string :account_tier
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :xbox_accounts, :xbox_id, unique: true
  end
end
