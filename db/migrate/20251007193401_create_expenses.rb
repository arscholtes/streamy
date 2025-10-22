class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :amount_cents, null: false
      t.string :category, null: false
      t.text :description
      t.string :receipt_url
      t.date :date, null: false
      t.boolean :tax_deductible, default: false, null: false

      t.timestamps
    end

    add_index :expenses, [:user_id, :date]
    add_index :expenses, :category
    add_index :expenses, :tax_deductible
  end
end
