class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipient, foreign_key: { to_table: :users }
      t.string :stripe_payment_intent_id
      t.string :stripe_charge_id
      t.string :stripe_transfer_id
      t.integer :amount_cents, null: false
      t.integer :platform_fee_cents, default: 0
      t.integer :recipient_amount_cents
      t.string :currency, null: false, default: 'usd'
      t.string :status, null: false, default: 'pending'
      t.string :payment_type, null: false
      t.text :description
      t.json :metadata, default: {}
      t.datetime :refunded_at
      t.integer :refund_amount_cents

      t.timestamps
    end

    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :stripe_charge_id
    add_index :payments, :status
    add_index :payments, :payment_type
    add_index :payments, [:user_id, :payment_type]
    add_index :payments, [:recipient_id, :status]
  end
end
