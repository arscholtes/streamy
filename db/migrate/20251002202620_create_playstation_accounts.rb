class CreatePlaystationAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :playstation_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :psn_id
      t.string :online_id
      t.string :account_id
      t.string :region
      t.string :plus_status
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :playstation_accounts, :psn_id, unique: true
  end
end
