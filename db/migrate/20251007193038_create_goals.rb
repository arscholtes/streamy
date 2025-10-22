class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :goal_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :progress_type, null: false, default: 0
      t.decimal :current_value, precision: 10, scale: 2, default: 0.0
      t.decimal :target_value, precision: 10, scale: 2
      t.datetime :deadline
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :visibility, null: false, default: 0
      t.text :metadata

      t.timestamps
    end

    add_index :goals, :status
    add_index :goals, :goal_type
    add_index :goals, :deadline
  end
end
