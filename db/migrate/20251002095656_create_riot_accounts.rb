class CreateRiotAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :riot_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :puuid
      t.string :game_name
      t.string :tag_line
      t.string :region
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :riot_accounts, :puuid, unique: true
  end
end
