class CreatePaypalAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :paypal_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :paypal_id
      t.string :email
      t.boolean :verified
      t.string :account_type
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :paypal_accounts, :paypal_id, unique: true
  end
end
