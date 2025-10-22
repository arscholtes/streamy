class CreateGoalSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_steps do |t|
      t.references :goal, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false, default: 0
      t.boolean :completed, null: false, default: false

      t.timestamps
    end

    add_index :goal_steps, [:goal_id, :position], unique: true
  end
end
