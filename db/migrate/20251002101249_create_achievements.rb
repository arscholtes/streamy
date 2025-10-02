class CreateAchievements < ActiveRecord::Migration[8.0]
  def change
    create_table :achievements do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.string :icon
      t.string :category, null: false
      t.integer :points_reward, default: 0, null: false
      t.string :requirement_type, null: false
      t.integer :requirement_value, null: false

      t.timestamps
    end

    add_index :achievements, :name, unique: true
    add_index :achievements, :category
  end
end
