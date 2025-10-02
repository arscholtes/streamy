class CreateStreams < ActiveRecord::Migration[8.0]
  def change
    create_table :streams do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :status
      t.string :stream_key
      t.string :playback_path

      t.timestamps
    end
    add_index :streams, :stream_key
  end
end
