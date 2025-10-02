class CreateLoyaltyPoints < ActiveRecord::Migration[8.0]
  def change
    create_table :loyalty_points do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :points, default: 0, null: false
      t.integer :level, default: 1, null: false
      t.integer :total_earned, default: 0, null: false
      t.integer :total_spent, default: 0, null: false

      t.timestamps
    end
  end
end
