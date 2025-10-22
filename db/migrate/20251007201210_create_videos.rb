class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :video_url
      t.string :thumbnail_url
      t.integer :duration_seconds
      t.integer :view_count, default: 0
      t.string :status, default: 'processing'  # processing, published, unlisted, private
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :videos, :status
    add_index :videos, :view_count
    add_index :videos, :created_at
  end
end
