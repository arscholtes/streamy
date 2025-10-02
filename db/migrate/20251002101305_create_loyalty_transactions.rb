class CreateLoyaltyTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :loyalty_transactions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :transaction_type, null: false
      t.integer :amount, null: false
      t.text :description
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :loyalty_transactions, :transaction_type
    add_index :loyalty_transactions, :created_at
  end
end
