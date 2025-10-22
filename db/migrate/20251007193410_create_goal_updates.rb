class CreateGoalUpdates < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_updates do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :update_type, null: false, default: 0
      t.decimal :value_before, precision: 10, scale: 2
      t.decimal :value_after, precision: 10, scale: 2
      t.text :note

      t.timestamps
    end

    add_index :goal_updates, :created_at
  end
end
