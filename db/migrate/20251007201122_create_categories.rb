class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :image_url
      t.integer :live_count, default: 0
      t.integer :viewer_count, default: 0

      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :live_count
    add_index :categories, :viewer_count
  end
end
