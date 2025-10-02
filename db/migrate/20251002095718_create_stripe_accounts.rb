class CreateStripeAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_id
      t.string :email
      t.string :account_type
      t.boolean :charges_enabled
      t.boolean :payouts_enabled
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :stripe_accounts, :stripe_id, unique: true
  end
end
