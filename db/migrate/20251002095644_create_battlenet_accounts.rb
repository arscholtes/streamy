class CreateBattlenetAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :battlenet_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :battletag
      t.string :region
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :battlenet_accounts, :battletag, unique: true
  end
end
