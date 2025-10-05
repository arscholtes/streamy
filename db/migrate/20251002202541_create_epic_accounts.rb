class CreateEpicAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :epic_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :epic_id
      t.string :display_name
      t.string :email
      t.string :country
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :epic_accounts, :epic_id, unique: true
  end
end
