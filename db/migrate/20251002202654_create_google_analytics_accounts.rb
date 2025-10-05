class CreateGoogleAnalyticsAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :google_analytics_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :property_id
      t.string :account_id
      t.string :property_name
      t.string :tracking_id
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :google_analytics_accounts, :property_id, unique: true
  end
end
