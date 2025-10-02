class CreateSteamAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :steam_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :steam_id
      t.string :persona_name
      t.string :profile_url
      t.string :avatar_url
      t.string :real_name
      t.string :country_code
      t.string :state_code
      t.integer :visibility
      t.integer :time_created
      t.integer :last_logoff
      t.integer :level
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :steam_accounts, :steam_id, unique: true
  end
end
